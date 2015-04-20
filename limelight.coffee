Points = new Mongo.Collection("points")
QuizSessions = new Mongo.Collection("quizsessions")
@qs = QuizSessions
@pts = Points

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
		Session.set("insertedPoint", undefined)
		Session.set("emoji_id", undefined)
		Session.set("selected_language", undefined)
		Meteor.call "updateQuizSession", Session.get("quizDevice"), Session.get("quizStep"), Session.get("currentApiData")

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
		return el

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

	clearPoints = () ->
		$('.point').remove()

	doPointColors = () ->
		points = document.getElementsByClassName('point')
		icons = document.getElementsByClassName('building-icon')

		if points.length == 0 || icons.length == 0
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

				if closest
					color = closest.getAttribute('data-color')
					shapes = [].slice.call(point.firstChild.childNodes)
					for shape in shapes
						shape.setAttribute('fill', color)

	doPointColors()

	quizImages = (data, quizstep, num) ->
		if (!data)
			data = Session.get('currentApiData')
		# in the future, this would be solved by using Deps.Dependency
		if(data?)
			if((Session.get("img-" + num + "-step") || '') != quizstep)
				imgurl = globals.projection_img_dir + data.next_question[0].q_id + "/"
				if(num == 1)
					imgurl += data.next_question[0].a1_id
				else
					imgurl += data.next_question[0].a2_id
				imgurl += "-"
				imgurl +=  _.random(1, globals.projection_img_count[data.next_question[0].q_id])
				imgurl += ".png"

				Session.set("img-" + num + "-step", quizstep)
				Session.set("img-" + num + "-img", imgurl)
				return imgurl
		return Session.get("img-" + num + "-img")

	# assume a[0] and b[0] are x, a[1] and b[1] are y
	distance = (a, b) ->
		x = b[0] - a[0]
		y = b[1] - a[1]
		d = Math.sqrt(x * x + y * y)
		return d


	# Helper vars
	xmlns = 'http://www.w3.org/2000/svg'

	Template.registerHelper "equals", (a, b) ->
		return (a == b)
	Template.registerHelper "notEquals", (a, b) ->
		return (a != b)

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
			Router.go('quiz', { quizDevice: this.quizDevice })

		# show and hide the modal
		"click [data-modal]": (event) ->
			showModal(event.target.getAttribute('data-modal'))
		"click [id^=modal]": (event) ->
			target = $(event.target)
			if target.attr('id') == event.currentTarget.id || target.closest('.close').length > 0
				$(event.currentTarget).fadeOut()


	Template.pindrop.helpers
		allpoints: () ->

			clearPoints()
			doPointColors()

			# make /pindrop/ipad* search for points from devices of ipad*
			if (this.quizDevice? and this.quizDevice != "default")
				pattern =
					quizDevice: { $regex: this.quizDevice }
			else
				pattern = {}
			numPoints = Points.find(pattern).count()
			Session.set('numPoints', numPoints)
			console.log(numPoints)
			return Points.find(pattern)

		renderBuildingIcons: () ->
			# fireice.fire/ used as dummy
			Meteor.call "checkApi", globals.apiBaseUrl + 'fireice.fire/', (err, results) ->
				guesses = results.data.guesses

				for guess in guesses

					index = globals.submissionIdOrder.indexOf(guess.submission_id)

					div = document.createElement('div')
					div.classList.add('building-icon')
					# get how far left it is -- if too far to the right,
					# the infobox shows up to the left instead of right
					left = remap(guess.coord[0], -1.3, 1.6)
					div.style.left = left + 'vw'
					div.style.top = remap(guess.coord[1], -1.3, 1.4) + 'vh'
					div.setAttribute('data-color', scoreColorById(guess.submission_id))
					div.setAttribute('data-ghid', guess.submission_id)

					infobox = document.createElement('div')
					infobox.classList.add('infobox')
					if window.innerWidth - left * window.innerWidth / 100 < 400
						infobox.style.left = '-100%'

					buildingImg = document.createElement('img')
					buildingImg.src = '/img/buildings/' + guess.submission_id + '.jpg'

					name = document.createElement('p')
					name.innerHTML = globals.buildingNames[index]
					infobox.appendChild(buildingImg)
					infobox.appendChild(name)

					div.appendChild(infobox)

					svg = makeSVG(
						viewBox: '0 0 200 200'
					)
					buildingShapes = globals.buildingIcons[index]

					activate = () ->
						$(this).closest('.building-icon').addClass('active')

					deactivate = () ->
						$(this).closest('.building-icon').removeClass('active')

					for shape in buildingShapes
						shape.attrs.fill = scoreColorById(guess.submission_id)
						shape = makeSVGelement(svg, shape)

						shape.addEventListener('mouseover', activate)
						shape.addEventListener('mouseout', deactivate)

					div.appendChild(svg)

					$(div).on "click", () ->
						window.open(globals.finalistBaseUrl + $(this).data("ghid"), "_blank")

					document.body.insertBefore(div, document.body.firstChild)

		renderPoint: () ->

			# create point container
			point = document.createElement('div')
			point.classList.add('point')
			point.style.left = this.pageX + 'vw'
			point.style.top = this.pageY + 'vh'
			point.setAttribute('data-id', this._id)

			if(window.location.hash)
				hash = window.location.hash.substring(1)
				if(hash == this._id)
					point.classList.add('hoverLock')

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
				quizTaker.innerHTML += if this.quizTakerAge then ', ' + this.quizTakerAge else ''
				point.appendChild(quizTaker)

				document.body.appendChild(point)
				return

		pointColors: () ->

			doPointColors()
			return

	Template.pindrop.rendered = ->

		if (!this._rendered)
			this._rendered = true;
			Session.set("pindropRendered", true)

		$('.bg-dummy').remove()
		# let 'ESC' close modal
		$(document).on('keydown', (e) ->
			if e.keyCode == 27
				$('[id^=modal]').fadeOut()
		)



	renderQuizBG = () ->

		body = $('body')
		dummy = $('.bg-dummy')
		which = randFromArray(svgKeys(20))

		$('.building-icon').remove()

		fadeDummy = () ->
			dummy.fadeIn(() ->
				body.css('background-image', 'url(/img/bg/background1440x1440-' + which + '.svg)')
				dummy.fadeOut()
			)

		body.prepend(dummy)
		fadeDummy()

	updateFromApi = (url, callback) ->
		Meteor.call "checkApi", url, (error, results) ->

			# save current results
			Session.set("currentApiData", results.data)

			console.log url
			console.log results.data

			# check if we're done
			if('next_question' of results.data and results.data.next_question.length <= 0)
				Session.set("apiQuestionsDone", true)

			# update quiz session for projection template
			console.log Session.get("quizDevice")
			Meteor.call "updateQuizSession", Session.get("quizDevice"), Session.get("quizStep"), Session.get("currentApiData")

			if(callback)
				callback()
		return

	countdownTimer = (selector, callback) ->
		t = new Date()
		t.setSeconds(t.getSeconds() + globals.countdownSecs)

		setTimeout(() ->
			$(selector).countdown t
				.on('update.countdown', (event) ->
					$(this).html(event.strftime('%S'))
				)
				.on('finish.countdown', (event) ->
					if(callback)
						callback()
				)
		, 1)


	Template.quiz.rendered = renderQuizBG

	Template.quiz.helpers
		isQuizKiosk: () ->
			if(this.quizKiosk? and this.quizKiosk != 'default')
				return true
			else
				return false

		quizStep: () ->
			renderQuizBG()
			if !(Session.get("quizStep"))
				quizInit(this)
			return Session.get("quizStep")

		quizImages: (data, quizstep, num) ->
+			return quizImages(data, quizstep, num)

		shouldShowQuestions: (step) ->
			if(step <= 1)
				return false
			if(step >= globals.quizTotalSteps - 3)
				return false
			return true


		quizQuestionData: () ->

			$('.step-choice button').prop('disabled', false)

			if !(Session.get("currentApiData"))
				updateFromApi(Session.get("apiUrl"))
				# we don't have to have a return to it because this will change when Session.get("currentApiData") changes
			else
				thisData = Session.get("currentApiData")
				next_q = thisData.next_question[0]
				if ((next_q?) and _.random(0, 1) == 1)
					tmpid = next_q.a1_id
					tmptext = next_q.a1_text
					next_q.a1_id = next_q.a2_id
					next_q.a1_text = next_q.a2_text
					next_q.a2_id = tmpid
					next_q.a2_text = tmptext
				thisData.next_question[0] = next_q

				#updating QuizSession so that projector order of images will match button order
				Session.set("currentApiData", thisData)
				Meteor.call "updateQuizSession", Session.get("quizDevice"), Session.get("quizStep"), Session.get("currentApiData")

				return next_q
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
			return !(Session.get('emoji_id')?)

		no_language_selected: () ->
			return !(Session.get('selected_language')?)

	endQuiz = () ->
		coord = Session.get("currentApiData").coord
		# rough x coords domain: -0.8 to 1.1,
		# y: -0.8 to 0.9
		x = remap(coord[0], -0.8, 1.1)
		y = remap(coord[1], -0.8, 0.9)

		console.log Session.get("quizTaker")
		console.log Session.get("quizTakerAge")
		pointid = Points.insert
			pageX: x
			pageY: y
			emoji_id: Session.get('emoji_id')
			quizHistory: Session.get("quizHistory")
			quizTaker: Session.get("quizTaker")
			quizTakerAge: Session.get("quizTakerAge")
			quizDevice: Session.get('quizDevice')

		console.log(pointid)

		document.body.style.backgroundImage = ''
		if(Session.get('quizDevice') == "default")
			Router.go('pindrop')
		else
			countdownTimer(".countdown", () ->
				quizInit({ quizDevice: Session.get('quizDevice') })
				Router.go('quiz', { quizDevice: Session.get('quizDevice') })
			)

	Template.quiz.events

		"click button.language-choice": (event) ->
			button_value = event.target.value
			Session.set('selected_language', button_value)
			Session.set("quizStep", Session.get("quizStep") + 1)
			Session.set("apiUrl", globals.apiBaseUrl + ">" + Session.get('selected_language') + "/")
			updateFromApi(Session.get("apiUrl"), () ->
				$('.step').fadeIn(150)
			)

		"click .step-choice button": (event) ->

			button_value = event.target.value

			# unfocus the button
			event.target.blur()

			# disable button until re-enabled with new data
			$('.step-choice button').prop('disabled', true);

			$('.step').fadeOut(150, () ->
				qH = Session.get("quizHistory")
				qH.push Session.get("currentApiData").next_question[0].q_id + "." + button_value

				Session.set("apiUrl", globals.apiBaseUrl + ">" + Session.get('selected_language') + ">" + qH.join(">") + "/")
				Session.set("quizHistory", qH)

				Session.set("quizStep", Session.get("quizStep") + 1)

				updateFromApi(Session.get("apiUrl"), () ->
					$('.step').fadeIn(150)
				)
			)

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
			console.log(emoji_id)
			Session.set("emoji_id", emoji_id)

			Session.set("quizStep", Session.get("quizStep") + 1)
			updateFromApi(Session.get("apiUrl"), () ->
				$('.step').fadeIn(150)
			)

			endQuiz()

		"click .submit-quizTakerAge": (event) ->
			event.preventDefault()
			Session.set("quizTakerAge", $('#quizTakerAge').val())

			Session.set("quizStep", Session.get("quizStep") + 1)
			updateFromApi(Session.get("apiUrl"), () ->
				$('.step').fadeIn(150)
			)


		"click .submit-quizTaker": (event) ->
			event.preventDefault()
			Session.set("quizTaker", $('#quiz-taker').val())

			Session.set("quizStep", Session.get("quizStep") + 1)
			updateFromApi(Session.get("apiUrl"), () ->
				$('.step').fadeIn(150)
			)


	Template.projection.helpers

		startCountdown: () ->
			countdownTimer(".countdown")
			return ""

		shouldShowImages: (step) ->
			if(step <= 1)
				return false
			if(step >= globals.quizTotalSteps - 3)
				return false
			return true

		quizImages: (data, quizstep, num) ->
			return quizImages(data, quizstep, num)

		scoreTest: (score) ->
			return Math.round(score * 100)

		scoreColorById: (id) ->
			return scoreColorById(id)

		projectionGuessesSort: (guesses) ->
			# sort the guesses by the submission_id's order in globals.submissionIdOrder
			if (guesses? && guesses.length > 0)
				return _.sortBy guesses, (d) ->
					return _.indexOf(globals.submissionIdOrder,d.submission_id )
			else
				return _.map globals.submissionIdOrder, (d) ->
					return {'submission_id': d, 'score': 0.0}


		projectionSession: () ->
			return QuizSessions.findOne({ quizdevice: this.quizDevice})

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
		updateQuizSession: (thisdevice, thisquizstep, thisapidata) ->
			QuizSessions.update(
				{ quizdevice: thisdevice },
				{ $set: { quizStep: thisquizstep, currentApiData: thisapidata } },
				{ upsert: true})
			return thisdevice + ":" + thisquizstep

		removeAllPoints: ->
			Points.remove({})
			QuizSessions.remove({})

		checkApi: (url) ->
			this.unblock();
			return Meteor.http.call("GET", url)



Router.map ->

	this.route 'pindropExhibit',
		path: '/pindrop/:quizDevice?',
		layoutTemplate: 'pindrop'
		onBeforeAction: () ->
			document.body.classList.add('pindrop')
			this.next()
		data: ->
			return { quizDevice : this.params.quizDevice || 'default' }

	this.route 'pindrop',
		path: '/',
		layoutTemplate: 'pindrop'
		onBeforeAction: () ->
			document.body.classList.add('pindrop')
			this.next()

	this.route 'quiz',
		path: '/quiz/:quizDevice?' #question mark makes parameter optional
		layoutTemplate: 'baseTemplate'
		yieldTemplate:
			'quiz': {to: 'quiz'}
		data: ->
			return { quizDevice : this.params.quizDevice || 'default' }
		onBeforeAction: () ->
			theClass = 'quiz-' + if this.params.quizDevice then 'ipad' else 'web'
			document.body.classList.add(theClass)
			this.next()

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
