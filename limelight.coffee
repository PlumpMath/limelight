Points = new Mongo.Collection("points")

if Meteor.isClient 

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
		Session.set("quizStep", 1)
		Session.set("quizAnswers", [])
		$(".step").hide()
		$(".initial-step").show()

	Template.quiz.helpers
		quizStep: () ->
			if !(Session.get("quizStep"))
				quizInit()
			return Session.get("quizStep")	
		quizAnswers: () ->
			return Session.get("quizAnswers")	
		quizProcessed: () ->

			if Session.get("quizStep") == "DONE"
				qA = Session.get("quizAnswers")	

				#HACKY TEST
				if qA[0] == "Karl Marx"
					x = _.random(0, 300, true)
				else 
					x = _.random(300, 600, true)

				if qA[1] == "Corbusier"
					y = _.random(0, 300, true)
				else 
					y = _.random(300, 600, true)

				if qA[2] == "Piketty"
					r = _.random(0, 5, true)
				else 
					r = _.random(10, 20, true)

				
				Points.insert
					pageX: x
					pageY: y
					radius: r
					qA: qA
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
			bname = event.target.name

			qA = Session.get("quizAnswers")
			qA.push event.target.innerHTML
			Session.set("quizAnswers", qA)
			console.log qA 

			$(event.target).parent().hide()

			if Session.get("quizStep") < 3
				Session.set("quizStep", Session.get("quizStep") + 1)
				$("#step-" + Session.get("quizStep")).fadeIn(1000)
			else
				Session.set("quizStep", "DONE")
				$(".final-step").fadeIn(1000)

if Meteor.isServer
	Meteor.methods
		removeAllPoints: ->
			Points.remove({})

			

Router.map ->
	this.route 'home', {path: '/'}  
	this.route 'hello', {path: '/hellohello'}  
	this.route 'pindrop',
		path: '/pindrop'
		layoutTemplate: 'baseTemplate'
		yieldTemplate:
			'pindrop': {to: 'pindrop'}
	this.route 'quiz',
		path: '/quiz/:quizTaker'
		layoutTemplate: 'baseTemplate'
		yieldTemplate:
			'quiz': {to: 'quiz'}
		data: ->
			return { quizTaker : this.params.quizTaker }



