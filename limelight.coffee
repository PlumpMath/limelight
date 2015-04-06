Points = new Mongo.Collection("points")

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

	quizInit = ->
		Session.set("currentApiData", undefined)
		Session.set("quizStep", 1)
		Session.set("quizHistory", [])
		Session.set("apiUrl", globals.apiBaseUrl)
		$(".step").hide()
		$(".initial-step").show()

	updateFromApi = (url) ->
		Meteor.call "checkApi", url, (error, results) ->
			console.log(results)
			Session.set("currentApiData", results.data)
			if('next_question' of results.data and results.data.next_question.length <= 0)
				Session.set("quizStep", globals.quizStepDone)
		return

	Template.quiz.helpers
		quizStep: () ->
			if !(Session.get("quizStep"))
				quizInit()
			return Session.get("quizStep")	
		quizQuestionData: () ->
			if !(Session.get("currentApiData"))
				updateFromApi(Session.get("apiUrl"))
			else
				return Session.get("currentApiData").next_question[0]
		quizGuesses: () ->
			if (Session.get("currentApiData"))
				return Session.get("currentApiData").guesses
		quizHistory: () ->
			return Session.get("quizHistory")	
		quizProcessed: () ->

			if Session.get("quizStep") == globals.quizStepDone
				qH = Session.get("quizHistory")	

				#HACKY TEST - REAL API GOES HERE
				if qH[0] == "Karl Marx"
					x = _.random(0, 300, true)
				else 
					x = _.random(300, 600, true)

				if qH[1] == "Corbusier"
					y = _.random(0, 300, true)
				else 
					y = _.random(300, 600, true)

				if qH[2] == "Piketty"
					r = _.random(0, 5, true)
				else 
					r = _.random(10, 20, true)

				
				Points.insert
					pageX: x
					pageY: y
					radius: r
					qH: qH
					quizTaker: this.quizTaker

				return x + ":" + y + ":" + r

	Template.quiz.events
		"click button.delete": ->
			r = confirm("Delete all points? This cannot be undone.")
			if r == true
				Meteor.call "removeAllPoints"
				quizInit()

		"click button.restart": (event) ->
			quizInit()
			return

		"click button.step-choice": (event) ->

			button_value = event.target.value

			qH = Session.get("quizHistory")
			qH.push Session.get("currentApiData").next_question[0].qid + "." + button_value

			Session.set("apiUrl", globals.apiBaseUrl + qH.join(">"))
			Session.set("quizHistory", qH)

			Session.set("quizStep", Session.get("quizStep") + 1)

			updateFromApi(Session.get("apiUrl"))




if Meteor.isServer
	Meteor.methods
		removeAllPoints: ->
			Points.remove({})

		checkApi: (url) ->
			this.unblock();
			return Meteor.http.call("GET", url)

			

Router.map ->
	this.route 'hello', {path: '/hellohello'}  
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



