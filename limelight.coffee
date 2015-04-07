Points = new Mongo.Collection("points")
QuizSessions = new Mongo.Collection("quizsessions")
@qs = QuizSessions

if Meteor.isClient 
	l = (string) ->
		return string.toLocaleString();

	Template.pindrop.events
		"click div": (event) ->
			Points.insert
				pageX: event.pageX
				pageY: event.pageY

	Template.pindrop.helpers
		allpoints: () ->
			return Points.find({})

	Template.pindrop.rendered = ->
		if(!this._rendered) 
			this._rendered = true;
			Session.set("pindropRendered", true)
			console.log('Template onLoad')

	Template.point.created = ->
		if Session.get("pindropRendered") == true
			console.log this
			console.log this.data.pageX
			console.log this.data.pageY
			$("<img>")
				.addClass("explosion")
				.css("left", this.data.pageX + "px")
				.css("top", this.data.pageY + "px")
				.attr("src", "/img/glitter.gif")
				.hide()
				.appendTo("#drop-canvas")
				.fadeIn(1000)
				.fadeOut(1000)
			console.log "who#a"

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
			console.log(results)

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
			if !(Session.get("currentApiData"))
				updateFromApi(Session.get("apiUrl"))
			else
				return Session.get("currentApiData").next_question[0]
		quizGuesses: () ->
			if(Session.get("currentApiData"))
				return Session.get("currentApiData").guesses
			console.log(Session.get("quizStep"))
			return
		quizHistory: () ->
			return Session.get("quizHistory")	
		quizProcessed: () ->

			if Session.get("quizStep") == globals.quizStepDone
				qH = Session.get("quizHistory")	

				coord = Session.get("currentApiData").coord
				# rough x coords domain: -0.8 to 1.1, 
				# y: -0.8 to 0.9
				x = (coord[0] + 0.5) * 500
				y = (coord[1] + 0.5) * 500

				Points.insert
					pageX: x
					pageY: y
					qH: qH
					quizTaker: this.quizTaker

				return x + ":" + y 

	Template.quiz.events

		"click button.step-choice": (event) ->

			button_value = event.target.value

			qH = Session.get("quizHistory")
			qH.push Session.get("currentApiData").next_question[0].qid + "." + button_value

			Session.set("apiUrl", globals.apiBaseUrl + qH.join(">") + "/")
			Session.set("quizHistory", qH)

			Session.set("quizStep", Session.get("quizStep") + 1)

			updateFromApi(Session.get("apiUrl"))

		"click button.delete": ->
			r = confirm("Delete all points? This cannot be undone.")
			if r == true
				Meteor.call "removeAllPoints"
				quizInit(this)

		"click button.restart": (event) ->
			quizInit(this)
			return


	Template.projection.helpers
		projectionSession: () ->
			return QuizSessions.findOne({ taker: this.quizTaker})
		
		projectionStep: () ->
			console.log(this)
			return "yo"


if Meteor.isServer
	Meteor.methods
		updateQuizSession: (thistaker, thisquizstep, thisapidata) ->
			console.log(thistaker)
			console.log(thisquizstep)
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
		layoutTemplate: 'baseTemplate'
		yieldTemplate:
			'pindrop': { to: 'pindrop'}

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



