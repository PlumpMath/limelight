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
		"click div": (event) ->

			# give it a random ID btw 1 and 24 inclusive
			id = Math.round(Math.random() * 23 + 1).toString()
			# leading 0 if there is not one
			if id.length == 1
				id = '0' + id

			Points.insert
				pageX: event.pageX * ( 100 / window.innerWidth )
				pageY: event.pageY * ( 100 / window.innerHeight )
				id: id

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

			quizTaker = document.createElement('p')
			quizTaker.classList.add('quiz-taker')
			quizTaker.innerHTML = this.quizTaker
			point.appendChild(quizTaker)

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


			quadrantColors = ['#00BDD4', '#FBEB34', '#6EC829', '#FAB0C9', '#FFAF3E', '#925D9E']

			# create SVG element
			svg = document.createElementNS(xmlns, 'svg')
			svg.setAttribute('viewBox', '0 0 283.46 283.46')
			svg.setAttribute('xmlns:xlink', 'http://www.w3.org/1999/xlink')
			svg.classList.add('emoji')
			point.appendChild(svg)

			thisContent = globals.svgContent[this.id]

			for shape in thisContent then do (shape) =>
				el = document.createElementNS(xmlns, shape.type)
				for attr, val of shape.attrs
					el.setAttribute(attr, val)
				# TODO: color
				el.setAttribute('fill', quadrantColors[quadrant - 1])
				svg.appendChild(el)
			document.body.appendChild(point)
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

		$(".step").hide()
		$(".initial-step").show()

	updateFromApi = (url) ->
		Meteor.call "checkApi", url, (error, results) ->

			# save current results
			Session.set("currentApiData", results.data)
			#console.log(results)

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
			$('button.step-choice').prop('disabled', false)
			if !(Session.get("currentApiData"))
				updateFromApi(Session.get("apiUrl"))
			else
				return Session.get("currentApiData").next_question[0]
		quizGuesses: () ->
			if(Session.get("currentApiData"))
				return Session.get("currentApiData").guesses
			#console.log(Session.get("quizStep"))
			return
		quizHistory: () ->
			return Session.get("quizHistory")
		quizProcessed: () ->

			if Session.get("quizStep") == globals.quizStepDone
				qH = Session.get("quizHistory")

				coord = Session.get("currentApiData").coord
				# rough x coords domain: -0.8 to 1.1,
				# y: -0.8 to 0.9
				x = remap(coord[0], -0.8, 1.1)
				y = remap(coord[1], -0.8, 0.9)

				# give it a random ID btw 1 and 24 inclusive
				id = Math.round(Math.random() * 23 + 1).toString()
				# leading 0 if there is not one
				if id.length == 1
					id = '0' + id

				Points.insert
					pageX: x
					pageY: y
					id: id
					qH: qH
					quizTaker: this.quizTaker

				return x + ":" + y
		totalSteps: () ->
			# or whatever it actually is... should it be in globals.quizStepDone?
			return 16

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


	Template.projection.helpers
		projectionSession: () ->
			return QuizSessions.findOne({ taker: this.quizTaker})

		projectionStep: () ->
			#console.log(this)
			return "yo"


if Meteor.isServer
	Meteor.methods
		updateQuizSession: (thistaker, thisquizstep, thisapidata) ->
			#console.log(thistaker)
			#console.log(thisquizstep)
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
		data: ->
			return { quizTaker : this.params.quizTaker }
