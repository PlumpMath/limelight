Points = new Mongo.Collection("points")
QuizSessions = new Mongo.Collection("quizsessions")
@qs = QuizSessions

if Meteor.isClient

	# Helper functions

	l = (string) ->
		return string.toLocaleString();

	quizInit = (that) ->
		Session.set("quizStep", 1)
		Session.set("apiQuestionsDone", false)
		Session.set("quizHistory", [])
		Session.set("apiUrl", globals.apiBaseUrl)
		Session.set("quizDevice", that.quizDevice)
		# all of these will be set during the quiz
		Session.set("currentApiData", undefined)
		Session.set("quizTaker", undefined)
		Session.set("insertedPoint", undefined)
		Session.set("emoji_id", undefined)
		Session.set("selected_language", undefined)

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

	scoreColorById = (id) ->
		index = globals.submissionIdOrder.indexOf(id)
		color = globals.colors[index]
		return color

	scoreIdByColor = (color) ->
		index = globals.colors[color]
		id = globals.submissionIdOrder[index]
		return id

	# assume a[0] and b[0] are x, a[1] and b[1] are y
	distance = (a, b) ->
		x = b[0] - a[0]
		y = b[1] - a[1]
		d = Math.sqrt(x * x + y * y)
		return d


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
		renderBuildingIcons: () ->
			# fireice.fire/ used as dummy
			Meteor.call "checkApi", globals.apiBaseUrl + 'fireice.fire/', (err, results) ->
				guesses = results.data.guesses

				for guess in guesses

					div = document.createElement('div')
					div.classList.add('building-icon')
					div.style.left = remap(guess.coord[0], -1.3, 1.6) + 'vw'
					div.style.top = remap(guess.coord[1], -1.3, 1.4) + 'vh'
					div.setAttribute('data-color', scoreColorById(guess.submission_id))

					img = document.createElement('img')
					img.src = '/img/building_icons/' + guess.submission_id + '.svg'
					div.appendChild(img)
					document.body.insertBefore(div, document.body.firstChild)

		renderPoint: () ->

			# create point container
			point = document.createElement('div')
			point.classList.add('point')
			point.style.left = this.pageX + 'vw'
			point.style.top = this.pageY + 'vh'

			# create SVG element
			svg = makeSVG(
				'class': 'emoji'
				'viewBox': '0 0 283.46 283.46'
			)
			point.appendChild(svg)

			thisContent = globals.svgContent[this.emoji_id]

			if thisContent
				for shape in thisContent then do (shape) =>
					shape.attrs.fill = 'transparent'
					makeSVGelement(svg, shape)

				quizTaker = document.createElement('p')
				quizTaker.classList.add('quiz-taker')
				quizTaker.innerHTML = this.quizTaker || 'anonymous'
				point.appendChild(quizTaker)

				document.body.appendChild(point)
			# need to return an empty string even though add the above SVG
			return ''

		pointColors: () ->
			doPointColors = () ->
				points = document.getElementsByClassName('point')
				icons = document.getElementsByClassName('building-icon')

				if points.length == 0
					setTimeout(doPointColors, 500)
				else

					points = [].slice.call(points)
					icons = [].slice.call(icons)

					for point in points

						dist = Infinity
						ptX = parseFloat(point.style.left)
						ptY = parseFloat(point.style.top)

						for icon in icons

							iconX = parseFloat(icon.style.left)
							iconY = parseFloat(icon.style.top)
							theDistance = distance([ptX, ptY], [iconX, iconY])

							if theDistance < dist
								dist = theDistance
								closest = icon

						color = closest.getAttribute('data-color')
						shapes = [].slice.call(point.firstChild.childNodes)
						for shape in shapes
							shape.setAttribute('fill', color)
			doPointColors()
			return ''

			#pointArr = Array.prototype.slice.call(points.childNodes)
			#console.log(pointArr)

	Template.pindrop.rendered = ->
		if (!this._rendered)
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
				Session.set("apiQuestionsDone", true)

			# update quiz session for projection template
			Meteor.call "updateQuizSession", Session.get("quizTaker"), Session.get("quizStep"), Session.get("currentApiData")
		return

	Template.quiz.rendered = renderQuizBG

	Template.quiz.helpers
		quizStep: () ->
			renderQuizBG()
			if !(Session.get("quizStep"))
				quizInit(this)
			return Session.get("quizStep")
		quizQuestionData: () ->

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
		apiQuestionsDone: () ->
			return Session.get("apiQuestionsDone")
		totalSteps: () ->
			return globals.quizTotalSteps

		svgKeys: () ->
			return svgKeys()

		no_emoji_id: () ->
			return (! Session.get('emoji_id'))

		no_language_selected: () ->
			return (! Session.get('selected_language'))

	Template.quiz.events

		"click button.language-choice": (event) ->
			button_value = event.target.value
			Session.set('selected_language', button_value)
			Session.set("quizStep", Session.get("quizStep") + 1)

		"click button.step-choice": (event) ->

			button_value = event.target.value

			# disable button until re-enabled with new data
			$('button.step-choice').prop('disabled', true);

			qH = Session.get("quizHistory")
			qH.push Session.get("currentApiData").next_question[0].qid + "." + button_value

			Session.set("apiUrl", globals.apiBaseUrl + qH.join(">") + "/")
			console.log(Session.get('apiUrl'))
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
			Session.set("quizStep", Session.get("quizStep") + 1)

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


		scoreTest: (score) ->
			return Math.round(score * 100)

		scoreColorById: (id) ->
			return scoreColorById(id)

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
