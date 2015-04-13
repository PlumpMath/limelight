Points = new Mongo.Collection("points")
QuizSessions = new Mongo.Collection("quizsessions")
@qs = QuizSessions

if Meteor.isClient

	# Helper functions

	l = (string) ->
		return string.toLocaleString();

	quizInit = (that) ->
		Session.set("quizStep", 1)
		Session.set("quizHistory", [])
		Session.set("apiUrl", globals.apiBaseUrl)
		Session.set("quizDevice", that.quizDevice)
		# all of these will be set during the quiz
		Session.set("currentApiData", undefined)
		Session.set("quizTaker", undefined)
		Session.set("insertedPoint", undefined)
		Session.set("emoji_id", undefined)

	# given min and max bounds, map a number n
	# onto 0 --> 100
	remap = (n, min, max) ->
		return ( n + 0.5 * (max - min) ) * ( 100 / (max - min) );

	randFromArray = (arr) ->
		return arr[Math.floor(Math.random() * arr.length)]

	sameInArray = (arr, item1, item2) ->
		return arr.indexOf(item1) == arr.indexOf(item2)

	# create an SVG to insert into the DOM
	makeSVG = (attrs) ->
		svg = document.createElementNS(xmlns, 'svg')
		# default namespace
		svg.setAttribute('xmlns:xlink', 'http://www.w3.org/1999/xlink')
		for key, value of attrs
			svg.setAttribute(key, value)
		return svg

	# create an SVG element
	makeSVGelement = (svg, obj) ->
		# obj expects:
		# {
		#	type: 'tag'
		#	attrs: {
		#		key: value (etc.)
		# 	}
		# }
		el = document.createElementNS(xmlns, obj.type)
		for key, value of obj.attrs
			el.setAttribute(key, value)
		svg.appendChild(el)

	# HACKY. Get the keys for all the SVG emoji icons ('01' -> '24' (or howMany))
	# 24 a default for the emoji icons, otherwise pass through # as arg
	svgKeys = (howMany) ->
		i = 1
		keys = []
		if !howMany
			howMany = 24
		while i <= howMany
			k = ''
			if i.toString().length == 1
				k = '0'
			k += i.toString()
			keys.push(k)
			i += 1
		return keys

	showModal = (which) ->
		$('#modal-' + which).fadeIn()


	# Helper vars
	xmlns = 'http://www.w3.org/2000/svg'

	Template.pindrop.events
		# testing only
		"click #drop-canvas": (event) ->

			# give it a random ID btw 0 and 23 inclusive
			emoji_id = Math.round(Math.random() * 23).toString()

			Points.insert
				pageX: event.pageX * ( 100 / window.innerWidth )
				pageY: event.pageY * ( 100 / window.innerHeight )
				emoji_id: emoji_id

		"click .restart": (event) ->
			$('.point').remove()
			Router.go('quiz', { quizDevice: 'a' })

		# show and hide the modal
		"click [data-modal]": (event) ->
			showModal(event.target.getAttribute('data-modal'))
		"click [id^=modal]": (event) ->
			target = $(event.target)
			if target.attr('id') == event.currentTarget.id || target.closest('.close').length > 0
				$(event.currentTarget).fadeOut()


	Template.pindrop.helpers
		allpoints: () ->
			return Points.find({})
		renderPoint: () ->

			# create point container
			point = document.createElement('div')
			point.classList.add('point')
			point.style.left = this.pageX + 'vw'
			point.style.top = this.pageY + 'vh'

			if this.pageX < 50
				if this.pageY < 50 && this.pageY < 1.5 * this.pageX
					quadrant = 1 # blue
				else if this.pageY >= 50 && 100 - this.pageY < 1.5 * this.pageX
					quadrant = 5 # orange
				else
					quadrant = 6 #purple
			if this.pageX >= 50
				if this.pageY < 50 && this.pageY < 1.5 * (100 - this.pageX)
					quadrant = 2 # yellow
				else if this.pageY >= 50 && 100 - this.pageY <= 1.5 * (100 - this.pageX)
					quadrant = 4 # pink
				else
					quadrant = 3 # green

			# create SVG element
			svg = makeSVG(
				'class': 'emoji'
				'viewBox': '0 0 283.46 283.46'
			)
			point.appendChild(svg)

			thisContent = globals.svgContent[this.emoji_id]

			if thisContent
				for shape in thisContent then do (shape) =>
					shape.attrs.fill = globals.colors[quadrant - 1]
					makeSVGelement(svg, shape)

			quizTaker = document.createElement('p')
			quizTaker.classList.add('quiz-taker')
			quizTaker.innerHTML = this.quizTaker || 'anonymous'
			point.appendChild(quizTaker)

			document.body.appendChild(point)
			# need to return an empty string even though add the above SVG
			return ''

	Template.pindrop.rendered = ->
		if(!this._rendered)
			this._rendered = true;
			Session.set("pindropRendered", true)

	renderQuizBG = () ->

		old = $('.bg')
		old.remove()

		which = randFromArray(svgKeys(20))
		console.log(which)
		#which = randFromArray(['1AB', '2AB', '2BC', '3AB'])
		#color = randFromArray(['blue', 'green', 'orange', 'pink', 'purple', 'yellow'])

		document.body.style.backgroundImage = 'url(/img/bg/background1440x1440-' + which + '.svg)'

	updateFromApi = (url) ->
		Meteor.call "checkApi", url, (error, results) ->

			# save current results
			Session.set("currentApiData", results.data)

			# check if we're done
			if('next_question' of results.data and results.data.next_question.length <= 0)
				Session.set("quizStep", globals.quizStepDone)

			# update quiz session for projection template
			Meteor.call "updateQuizSession", Session.get("quizTaker"), Session.get("quizStep"), Session.get("currentApiData")
		return

	Template.quiz.helpers
		quizStep: () ->
			if !(Session.get("quizStep"))
				quizInit(this)
			return Session.get("quizStep")
		quizQuestionData: () ->

			renderQuizBG()

			$('button.step-choice').prop('disabled', false)

			if !(Session.get("currentApiData"))
				updateFromApi(Session.get("apiUrl"))
			else
				return Session.get("currentApiData").next_question[0]
		quizGuesses: () ->
			if(Session.get("currentApiData"))
				return Session.get("currentApiData").guesses

		quizHistory: () ->
			return Session.get("quizHistory")
		quizDone: () ->
			return Session.get("quizStep") == globals.quizStepDone
		totalSteps: () ->
			return globals.quizTotalSteps

		svgKeys: () ->
			return svgKeys()

		no_emoji_id: () ->

			if Session.get('emoji_id')
				return false
			else
				return true

	Template.quiz.events

		"click button.step-choice": (event) ->

			button_value = event.target.value

			# disable button until re-enabled with new data
			$('button.step-choice').prop('disabled', true);

			qH = Session.get("quizHistory")
			qH.push Session.get("currentApiData").next_question[0].qid + "." + button_value

			Session.set("apiUrl", globals.apiBaseUrl + qH.join(">") + "/")
			Session.set("quizHistory", qH)

			Session.set("quizStep", Session.get("quizStep") + 1)

			updateFromApi(Session.get("apiUrl"))

			# unfocus the button
			event.target.blur()

		"click button.delete": ->
			r = confirm("Delete all points? This cannot be undone.")
			if r == true
				Meteor.call "removeAllPoints"
				quizInit()

		"click .restart": (event) ->
			Router.go('quiz', { quizDevice: Session.get('quizDevice') })
			quizInit({ quizDevice: Session.get('quizDevice') })

		"click .emoji": (event) ->
			# the data-id is of the form '01' to '24',
			# so coerce a string and subtract one
			# (for zero-based array)
			emoji_id = (+this.toString()) - 1
			Session.set("emoji_id", emoji_id)

		"click .submit-quizTaker": (event) ->
			event.preventDefault()
			quizTaker = document.getElementById('quiz-taker').value

			qH = Session.get("quizHistory")

			coord = Session.get("currentApiData").coord
			# rough x coords domain: -0.8 to 1.1,
			# y: -0.8 to 0.9
			x = remap(coord[0], -0.8, 1.1)
			y = remap(coord[1], -0.8, 0.9)

			Points.insert
				pageX: x
				pageY: y
				emoji_id: Session.get('emoji_id')
				qH: qH
				quizTaker: quizTaker

			document.body.style.backgroundImage = ''
			console.log Session.get('quizDevice')
			if(Session.get('quizDevice') == "default")
				Router.go('pindrop')
			else
				Router.go('quiz', { quizDevice: Session.get('quizDevice') })
				quizInit({ quizDevice: Session.get('quizDevice') })

	Template.projection.helpers

		quizStep: () ->
			if !(Session.get("quizStep"))
				quizInit(this)
			return Session.get("quizStep")

		scoreTest: (score) ->
			return Math.round(score * 100)

		scoreColorById: (id) ->
			index = globals.submissionIdOrder.indexOf(id)
			color = globals.colors[index]
			return color

		projectionGuessesSort: (guesses) ->
			# sort the guesses by the submission_id's order in globals.submissionIdOrder
			return _.sortBy guesses, (d) ->
				return _.indexOf(globals.submissionIdOrder,d.submission_id )

		projectionSession: () ->
			return QuizSessions.findOne({ taker: this.quizTaker})

		totalSteps: () ->
			return globals.quizTotalSteps

	# Futura web font
	wf = {}
	wf.monotype = { projectId: 'b07fd47e-b2bf-49ff-9312-8d7e6478a960' }
	window.WebFontConfig = wf
	do ()->
		wf = document.createElement('script')
		wf.src = '//ajax.googleapis.com/ajax/libs/webfont/1.5.10/webfont.js'
		wf.type = 'text/javascript'
		wf.async = 'true'
		s = document.getElementsByTagName('script')[0]
		s.parentNode.insertBefore(wf, s)


if Meteor.isServer
	Meteor.methods
		updateQuizSession: (thistaker, thisquizstep, thisapidata) ->
			QuizSessions.update(
				{ taker: thistaker },
				{ $set: { quizStep: thisquizstep, currentApiData: thisapidata } },
				{ upsert: true})
			return thistaker + ":" + thisquizstep

		removeAllPoints: ->
			Points.remove({})
			QuizSessions.remove({})

		checkApi: (url) ->
			this.unblock();
			return Meteor.http.call("GET", url)



Router.map ->

	this.route 'pindrop',
		path: '/pindrop',
		layoutTemplate: 'pindrop'
		#yieldTemplate:
		#	'pindrop': { to: 'pindrop'}

	this.route 'quiz',
		path: '/quiz/:quizDevice?' #question mark makes parameter optional
		layoutTemplate: 'baseTemplate'
		yieldTemplate:
			'quiz': {to: 'quiz'}
		data: ->
			return { quizDevice : this.params.quizDevice || 'default' }

	this.route 'projection',
		path: '/projection/:quizDevice'
		layoutTemplate: 'baseTemplate'
		yieldTemplate:
			'projection': {to: 'projection'}
		onBeforeAction: () ->
			document.body.classList.add('projection')
			this.next()
		data: ->
			return { quizDevice : this.params.quizDevice }
