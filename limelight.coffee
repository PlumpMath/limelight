Points = new Mongo.Collection("points")
QuizSessions = new Mongo.Collection("quizsessions")
@qs = QuizSessions

if Meteor.isClient

	# Helper functions

	l = (string) ->
		return string.toLocaleString();

	# given min and max bounds, map a number n
	# onto 0 --> 100
	remap = (n, min, max) ->
		return ( n + 0.5 * (max - min) ) * ( 100 / (max - min) );

	# testing only
	Template.pindrop.events
		"click #drop-canvas": (event) ->

			# give it a random ID btw 0 and 23 inclusive
			emoji_id = Math.round(Math.random() * 23).toString()

			Points.insert
				pageX: event.pageX * ( 100 / window.innerWidth )
				pageY: event.pageY * ( 100 / window.innerHeight )
				emoji_id: emoji_id

	Template.pindrop.helpers
		allpoints: () ->
			return Points.find({})
		renderPoint: () ->

			# for ref
			xmlns = 'http://www.w3.org/2000/svg'

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
			svg = document.createElementNS(xmlns, 'svg')
			svg.setAttribute('viewBox', '0 0 283.46 283.46')
			svg.setAttribute('xmlns:xlink', 'http://www.w3.org/1999/xlink')
			svg.classList.add('emoji')
			point.appendChild(svg)

			thisContent = globals.svgContent[this.emoji_id]

			for shape in thisContent then do (shape) =>
				el = document.createElementNS(xmlns, shape.type)
				for attr, val of shape.attrs
					el.setAttribute(attr, val)
				el.setAttribute('fill', globals.colors[quadrant - 1])
				svg.appendChild(el)

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
			console.log('Template onLoad')

	quizInit = (that) ->
		Session.set("currentApiData", undefined)
		Session.set("quizStep", 1)
		Session.set("quizHistory", [])
		Session.set("apiUrl", globals.apiBaseUrl)
		Session.set("quizTaker", that.quizTaker)
		Session.set("insertedPoint", undefined)

		$(".step").hide()
		$(".initial-step").show()

	randFromArray = (arr) ->
		return arr[Math.floor(Math.random() * arr.length)]

	sameInArray = (arr, item1, item2) ->
		return arr.indexOf(item1) == arr.indexOf(item2)


	renderQuizBG = () ->

		old = $('.bg')
		old.remove()

		#firstOld = old[0]
		#if old
		#	prevColor = firstOld.getAttribute('color')
		#	prevPaths = firstOld.getAttribute('paths')

		#color = randFromArray(globals.colors)
		#svgPaths = randFromArray(globals.svgBackgrounds)

		# make sure we don't use the old colors or the old paths
		#if sameInArray(globals.colors, color, prevColor)
		#	color = globals.colors[globals.colors.indexOf(color) + 1] || globals.colors[0]
		#if sameInArray(globals.svgBackgrounds, svgPaths, prevPaths)
		#	svgPaths = globals.svgBackgrounds[globals.svgBackgrounds.indexOf(svgPaths) + 1] || globals.svgPaths[0]

		color = randFromArray(globals.colors)
		svgPaths = randFromArray(globals.svgBackgrounds)
		#console.log(svgPaths)

		# for ref
		xmlns = 'http://www.w3.org/2000/svg'

		for shape in svgPaths then do (shape) =>

			# create SVG element
			svg = document.createElementNS(xmlns, 'svg')
			svg.setAttribute('viewBox', '0 0 203.553 143.759')
			svg.setAttribute('xmlns:xlink', 'http://www.w3.org/1999/xlink')
			svg.classList.add('bg')

			el = document.createElementNS(xmlns, shape.type)
			# set the path/shape attributes
			for attr, val of shape.attrs
				el.setAttribute(attr, val)
			# if there are classes, add a `corner` class
			if shape.classes
				svg.classList.add('corner')
			# then the appropriate `corner-` prefixed class
			for cl in shape.classes
				svg.classList.add('corner-' + cl)
			el.setAttribute('fill', color)
			svg.appendChild(el)

			document.body.insertBefore(svg, document.body.firstChild)


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

			if Session.get("quizStep") == globals.quizStepDone
				return true
			else
				return false
		totalSteps: () ->
			return globals.quizTotalSteps

		# HACKY. Get the keys for all the SVG emoji icons ('01' -> '24')
		svgKeys: () ->
			i = 1
			keys = []
			k = ''
			while i <= 24
				if i.toString().length == 1
					k = '0' + i.toString()
				else
					k = i.toString()
				keys.push(k)
				i += 1
			return keys

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
				quizInit(this)

		"click .restart": (event) ->
			quizInit(this)
			return

		"click .emoji": (event) ->

			if !(Session.get("insertedPoint"))
				console.log "clicked"

				# the data-id is of the form '01' to '24',
				# so coerce a string and subtract one
				# (for zero-based array)
				emoji_id = (+this.toString()) - 1

				qH = Session.get("quizHistory")

				coord = Session.get("currentApiData").coord
				# rough x coords domain: -0.8 to 1.1,
				# y: -0.8 to 0.9
				x = remap(coord[0], -0.8, 1.1)
				y = remap(coord[1], -0.8, 0.9)

				Points.insert
					pageX: x
					pageY: y
					emoji_id: emoji_id
					qH: qH
					quizTaker: this.quizTaker

				Session.set("insertedPoint", "true")
			# now need to gather name

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
		wf = document.createElement('script');
		wf.src = '//ajax.googleapis.com/ajax/libs/webfont/1.4.7/webfont.js';
		wf.type = 'text/javascript';
		wf.async = 'true';
		s = document.getElementsByTagName('script')[0];
		s.parentNode.insertBefore(wf, s);


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
		path: '/quiz/:quizTaker'
		layoutTemplate: 'baseTemplate'
		yieldTemplate:
			'quiz': {to: 'quiz'}
		data: ->
			return { quizTaker : this.params.quizTaker }

	this.route 'projection',
		path: '/projection/:quizTaker'
		layoutTemplate: 'baseTemplate'
		yieldTemplate:
			'projection': {to: 'projection'}
		onBeforeAction: () ->
			document.body.classList.add('projection')
			this.next()
		data: ->
			return { quizTaker : this.params.quizTaker }
