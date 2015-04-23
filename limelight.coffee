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
		Session.set("emoji_id", undefined)
		Session.set("selected_language", undefined)
		Session.set("quizStartTime", undefined)
		Session.set("img-1-caption", undefined)
		Session.set("img-2-caption", undefined)
		Session.set("img-history", {})

		# we do this here (as opposed to at endQuiz) because this call is async and we want to give it enough time
		Session.set("quizTakerIp", undefined)
		Meteor.call "getClientIp", (err, res) ->
			if(err)
				console.log err.reason
			else
				Session.set("quizTakerIp", res)

		Meteor.call "updateQuizSession", Session.get("quizDevice"), Session.get("quizStep"), Session.get("currentApiData"), Session.get("selected_language")

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

	showModal = (which, cb) ->
		# fade in the modal and execute a callback on it
		# (for example to inject content)
		modal = $('#modal-' + which)
		modal.fadeIn()
		if cb
			cb(modal)

	# wrapper specifically for the infobox
	showModalInfobox = (point, _this) ->
		showModal('infobox', ($modal) ->

			# clear previous info
			$modal.find('[data-fill]').html('')

			attrs = point[0].attributes
			for k, v of attrs
				# now get the *real* key and value
				key = v.name
				value = v.value
				if key && key.slice(0, 4) == 'data' && $modal.find('[' + key + ']')
					$modal.find('[' + key + ']').html(value)
					# parse date
					if key.toLowerCase() == 'data-quiztime'
						$modal.find('[' + key + ']').html(moment(value).format('MMM Do YYYY'))

			# update FB and TW share links
			$modal.find('.fb_icon a').attr('href', 'https://www.facebook.com/sharer/sharer.php?u=app.designguggenheimhelsinki.org%23' + _this._id)
			$modal.find('.twitter_icon a').attr('href', 'https://twitter.com/intent/tweet?text=Play%20the%20Guggenheim%20Helsinki%20Now%20Matchmaker%20Game%20and%20find%20the%20building%20for%20you!%20%23guggenheimhki%20app.designguggenheimhelsinki.org%2Fquiz%23' + _this._id)
		)

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


	# load an image for this q_id and this number (so step 9, number 2 = 9-2)
	# and then store it in session variable
	# next time we look for it, check for session var. This ensures that images are only selected once per q_id.
	# in the future, this would be solved by using Deps.Dependency
	Template.registerHelper "quizImages",  (data, num, projectionmobile) ->
		if (!data)
			data = Session.get('currentApiData')
		if(data?)

			if((Session.get("img-" + num + "-step") || '') != data.next_question[0].q_id)
				Session.set("img-" + num + "-step", data.next_question[0].q_id)

				if(projectionmobile == "projection")
					imgurl = globals.conceptimgs_projection_img_dir
					imgurl += data.next_question[0].q_id + "/"
					if(num == 1)
						imgurl += data.next_question[0].a1_id
					else
						imgurl += data.next_question[0].a2_id
					imgurl += "-"
					imgurl +=  _.random(1, globals.conceptimgs_img_count[data.next_question[0].q_id])
					imgurl += ".png"
				else
					if(num == 1)
						keydir = data.next_question[0].q_id + "/" + data.next_question[0].a1_id + "/"
					else
						keydir = data.next_question[0].q_id + "/" + data.next_question[0].a2_id + "/"
					imgfile = _.sample(globals.conceptimgs_mobile_img_filenames[keydir])
					imgurl = globals.conceptimgs_mobile_img_dir = "/img/conceptimgs-mobile/" + keydir + imgfile
					captionDecoded = $("<div/>").html(imgfile.split(".")[0]).text() #for the degree symbol

					Session.set("img-" + num + "-caption", captionDecoded)

				imghistory = Session.get("img-history")
				if(num == 1) 
					imghistory["img-" + data.next_question[0].q_id  + "-" + data.next_question[0].a1_id] = imgurl
				else
					imghistory["img-" + data.next_question[0].q_id  + "-" + data.next_question[0].a2_id] = imgurl
				Session.set("img-history", imghistory)

				Session.set("img-" + num + "-img", imgurl)
				return imgurl

		return Session.get("img-" + num + "-img")

	# Helper vars
	xmlns = 'http://www.w3.org/2000/svg'

	Template.registerHelper "equals", (a, b) ->
		return (a == b)
	Template.registerHelper "notEquals", (a, b) ->
		return (a != b)

	Template.registerHelper "isQuizKiosk", () ->
		if(Session.get("quizDevice")? and Session.get("quizDevice") != 'default')
			return true
		else
			return false


	Template.pindrop.events

		"click .restart": (event) ->
			$('.point').remove()
			quizInit({ quizDevice: Session.get('quizDevice') })
			Router.go('quiz', { quizDevice: this.quizDevice })

		# show and hide the modal
		"click [data-modal]": (event) ->
			showModal(event.target.getAttribute('data-modal'))
		"click [id^=modal]": (event) ->
			target = $(event.target)
			if target.attr('id') == event.currentTarget.id || target.closest('.close').length > 0
				$(event.currentTarget).fadeOut()

		"click .point": (event) ->

			_this = this
			point = $(event.target).closest('.point')

			showModalInfobox(point, _this)

			if !event.target.classList.contains('hoverLock')
				$('.hoverLock').removeClass('hoverLock')
				event.target.classList.add('hoverLock')
				window.location = '#' + this._id
			else
				event.target.classList.remove('hoverLock')
				window.location = '#'


	makeRegexPattern = (quizDevice) ->
		# make /pindrop/ipad* search for points from devices of ipad*
		if (quizDevice? and quizDevice != "default")
			pattern =
				quizDevice: { $regex: quizDevice }
		else
			pattern = {}
		return pattern


	Template.pindrop.helpers
		allpoints: () ->

			$('body').css('background-image', 'none')

			pattern = makeRegexPattern(this.quizDevice)
			numPoints = Points.find(pattern).count()
			Session.set('numPoints', numPoints)
			return Points.find(pattern, {sort:{quizTime: -1}})

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
					left = remap(guess.coord[0], globals.xCoordDomain[0], globals.xCoordDomain[1])
					div.style.left = left + 'vw'
					div.style.top = remap(guess.coord[1], globals.yCoordDomain[0], globals.yCoordDomain[1]) + 'vh'
					div.setAttribute('data-color', scoreColorById(guess.submission_id))
					div.setAttribute('data-ghid', guess.submission_id)

					infobox = document.createElement('div')
					infobox.classList.add('infobox')
					if window.innerWidth - left * window.innerWidth / 100 < 400
						infobox.style.left = '-100%'

					buildingImg = document.createElement('img')
					buildingImg.src = '/img/buildings/' + guess.submission_id + '.png'

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
						$(this).closest('.building-icon').addClass('active').appendTo('body')

					deactivate = () ->
						$(this).closest('.building-icon').removeClass('active').prependTo('body')

					div.appendChild(svg)

					for shape in buildingShapes
						shape.attrs.fill = scoreColorById(guess.submission_id)
						shape = makeSVGelement(svg, shape)

						shape.addEventListener('mouseover', activate)
						shape.addEventListener('mouseout', deactivate)
						shape.addEventListener('click', () ->
							window.open(
								globals.finalistBaseUrl + $(this).closest('.building-icon').data('ghid'),
								'_blank'
							)
						)

					document.body.insertBefore(div, document.body.firstChild)

	Template.pindrop.rendered = ->

		$('a.popup').click( (e) ->
			e.preventDefault();
			window.open(this.href, 'targetWindow',
				'toolbar=no,
				location=no,
				status=no,
				menubar=no,
				scrollbars=yes,
				resizable=yes,
				width=600,
				height=300');
		)

		checkBrandNew = () ->
			$('.point').each(() ->
				past = new Date(this.getAttribute('data-quiztime')).getTime()
				now = new Date().getTime()

				# if under 3 minutes old, it's brand new!
				if (now - past) / (60 * 1000) <= 3
					console.log('brand new')
				else
					this.classList.remove('brand-new')
			)

		setInterval(checkBrandNew, 10000)

		if (!this._rendered)
			this._rendered = true;
			Session.set("pindropRendered", true)

		$('.bg-dummy').remove()

		setTimeout(() ->
			document.body.classList.remove('preload')
		, 3000)

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

		fadeDummy()

	updateFromApi = (url, callback) ->
		Meteor.call "checkApi", url, (error, results) ->

			# swap the two questions here, so that it's also written into session and shown in the projection
			next_q = results.data.next_question[0]
			if ((next_q?) and _.random(0, 1) == 1)
				tmpid = next_q.a1_id
				tmptext = next_q.a1_text
				next_q.a1_id = next_q.a2_id
				next_q.a1_text = next_q.a2_text
				next_q.a2_id = tmpid
				next_q.a2_text = tmptext
			results.data.next_question[0] = next_q

			# save current results
			Session.set("currentApiData", results.data)

			# check if we're done
			if('next_question' of results.data and results.data.next_question.length <= 0)
				Session.set("apiQuestionsDone", true)

			# update quiz session for projection template
			Meteor.call "updateQuizSession", Session.get("quizDevice"), Session.get("quizStep"), Session.get("currentApiData"), Session.get("selected_language")

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


	Template.point.helpers
		timeFormat: (time) ->
			return moment(time).format('MMM Do YYYY')

		generateEmoji: (emoji_id, closestFinalist) ->

			# create SVG element
			svg = makeSVG(
				'class': 'emoji'
				'viewBox': '0 0 283.46 283.46'
			)
			svg.setAttribute('data-emoji_id', emoji_id)
			thisContent = globals.svgContent[emoji_id]

			finalistIndex = globals.submissionIdOrder.indexOf(closestFinalist)
			color = globals.colors[finalistIndex]

			if thisContent
				for shape in thisContent then do (shape) =>
					shape.attrs.fill = color
					makeSVGelement(svg, shape)

			# should be ok to move points last in DOM order and leave them there
			svg.setAttribute('onmouseover', "document.body.appendChild(this.parentNode)")

			tmp = document.createElement("div")
			tmp.appendChild(svg)

			return tmp.innerHTML

		pageCoord: (coords, axis) ->
			pageFactor = 1 # x/100 of window width/height -- point will vary by up to
						   # this much in both directions
			factor = 2 * pageFactor * ( Math.random() - 0.5 )
			
			return remap(
				coords[0],
				globals[axis + 'CoordDomain'][0],
				globals[axis + 'CoordDomain'][1]
			) + factor

		Template.point.rendered = ->

			id = this.data._id
			point = this.firstNode
			quizTime = this.data.quizTime

			if ( window.location.hash )
				hash = window.location.hash.substring(1)
				if (id == hash)
					point.classList.add('hoverLock')
					document.body.appendChild(point)
					showModalInfobox($(point), this)

			past = new Date(quizTime).getTime()
			now = new Date().getTime()

			# if under 3 minutes old, it's brand new!
			if (now - past) / (60 * 1000) <= 3
				point.classList.add('brand-new')
			else
				point.classList.remove('brand-new')

			# if over 1 hour old, scale up to 0.5, stay there
			stopAt = 72 # number of hours at which to stop scaling down (will stay at 0.5)

			if past + 60 * 60 * 1000 < now

				hours = (now - past) / (60 * 60 * 1000)

				scaleFactor = remap(hours, 1, stopAt)
				scaleFactor = 1 - (scaleFactor / 200)
				if scaleFactor < 0.4
					scaleFactor = 0.4

				[].slice.call(point.children).forEach((el) ->
					if el.classList.contains('emoji')
						el.style.transform = 'scale(' + scaleFactor + ')'
				)

			# if the user just came from the quiz, highlight theirs
			if Session.get('pointid') && id == Session.get('pointid')
				point.classList.add('current-user')


			$('.point').each((i) ->
				_this = this

				if i < 10
					this.classList.add('recent')
					this.children[1].style.opacity = ( 10 - i ) / 10
				else
					this.classList.remove('recent')

				setTimeout(() ->
					_this.classList.remove('loading')
				, Math.random() * 500 + 100)
			)



	Template.quiz.rendered = renderQuizBG

	Template.quiz.helpers

		quizStep: () ->
			if !(Session.get("quizStep"))
				quizInit(this)
			return Session.get("quizStep")

		selectedLanguage: () ->
			return Session.get('selected_language')

		shouldShowQuestions: (step) ->
			if(step <= 1)
				return false
			if(step >= globals.quizTotalSteps - 4)
				return false
			return true


		quizQuestionData: () ->

			$('.step-choice button').prop('disabled', false)

			if !(Session.get("currentApiData"))
				updateFromApi(Session.get("apiUrl"))
				# we don't have to have a return to it because this will change when Session.get("currentApiData") changes
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

		imgCaption: (num) ->
			return Session.get("img-" + num + "-caption")


		no_emoji_id: () ->
			return !(Session.get('emoji_id')?)

		no_language_selected: () ->
			return !(Session.get('selected_language')?)


	endQuiz = () ->
		coords = Session.get("currentApiData").coord

		closestFinalist = _.max(Session.get("currentApiData").guesses, (chr) ->
			return chr.score
			).submission_id

		endTime = new Date()


		pointid = Meteor.call "insertPoint",
			coords: coords
			emoji_id: Session.get('emoji_id')
			quizHistory: Session.get("quizHistory")
			imgHistory: Session.get('img-history')
			quizDevice: ( Session.get('quizDevice') || 'default' )
			quizTakerName: Session.get("quizTakerName")
			quizTakerAge: Session.get("quizTakerAge")
			quizTakerEmail: Session.get("quizTakerEmail")
			quizTakerTwitter: Session.get("quizTakerTwitter")
			quizTakerUpdateme: Session.get("quizTakerUpdateme")
			quizTakerIp: Session.get("quizTakerIp")
			quizTakerLanguage: Session.get("selected_language")
			quizTime: endTime
			quizDuration: (endTime.getTime() - Session.get("quizStartTime").getTime()) / 1000
			closestFinalist: closestFinalist

		$.get globals.bitlyApiUrl + encodeURIComponent(Meteor.absoluteUrl("#" + pointid)), (data) ->
			$(".bitlyurl").html(data)

		document.body.style.backgroundImage = ''
		if((Session.get('quizDevice') || 'default') == "default")
			console.log "yeah we're default"
			Router.go('pindrop', {},  { hash: pointid })
		else
			countdownTimer(".countdown", () ->
				quizInit({ quizDevice: Session.get('quizDevice') })
				Router.go('quiz', { quizDevice: Session.get('quizDevice') })
			)

	Template.quiz.events

		"click button.language-choice": (event) ->

			renderQuizBG()
			button_value = event.target.value
			Session.set('selected_language', button_value)
			Session.set("quizStep", Session.get("quizStep") + 1)
			Session.set("apiUrl", globals.apiBaseUrl + ">" + Session.get('selected_language') + "/")
			Session.set("quizStartTime", new Date())

			updateFromApi(Session.get("apiUrl"), () ->
				$('.step').fadeIn(150)
			)

		"click .step-choice button": (event) ->

			renderQuizBG()

			button_value = event.target.value

			# unfocus the button
			event.target.blur()

			# disable button until re-enabled with new data
			$('.step-choice button').prop('disabled', true);



			$('.step').fadeOut(150, () ->
				# clear the images until new ones come along
				Session.set("img-2-img", undefined)
				Session.set("img-1-img", undefined)

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
			renderQuizBG()
			quizInit({ quizDevice: Session.get('quizDevice') })
			Router.go('quiz', { quizDevice: Session.get('quizDevice') })

		"click .logo": (event) ->
			Router.go('pindrop')

		"click .emoji": (event) ->
			# the data-id is of the form '01' to '24',
			# so coerce a string and subtract one
			# (for zero-based array)
			emoji_id = (+this.toString()) - 1
			Session.set("emoji_id", emoji_id)

			Session.set("quizStep", Session.get("quizStep") + 1)
			updateFromApi(Session.get("apiUrl"), () ->
				$('.step').fadeIn(150)
			)


		"click button.submit-quizTakerAge": (event) ->
			event.preventDefault()
			renderQuizBG()
			Session.set("quizTakerAge", $('#quizTakerAge').val())

			Session.set("quizStep", Session.get("quizStep") + 1)
			updateFromApi(Session.get("apiUrl"), () ->
				$('.step').fadeIn(150)
			)


		"click .submit-quizTakerName": (event) ->
			event.preventDefault()
			renderQuizBG()
			Session.set("quizTakerName", $('#quiz-taker-name').val())

			Session.set("quizStep", Session.get("quizStep") + 1)
			updateFromApi(Session.get("apiUrl"), () ->
				$('.step').fadeIn(150)
			)


		"click .skip-quizTaker-info": (event) ->
			event.preventDefault()
			renderQuizBG()
			Session.set("quizTakerEmail", "SKIP")
			Session.set("quizTakerTwitter", "SKIP")
			Session.set("quizTakerUpdateme", "SKIP") #'SKIP' to distinguish between just a blank, which can be confusing when looking at the data later

			Session.set("quizStep", Session.get("quizStep") + 1)
			updateFromApi(Session.get("apiUrl"), () ->
				$('.step').fadeIn(150)
			)
			endQuiz()

		"click .submit-quizTaker-info": (event) ->
			event.preventDefault()
			renderQuizBG()
			Session.set("quizTakerEmail", $('#quiz-taker-email').val())
			Session.set("quizTakerTwitter", $('#quiz-taker-twitter').val())
			Session.set("quizTakerUpdateme", $('#quiz-taker-updateme').val())

			Session.set("quizStep", Session.get("quizStep") + 1)
			updateFromApi(Session.get("apiUrl"), () ->
				$('.step').fadeIn(150)
			)
			endQuiz()


	Template.projection.helpers

		startCountdown: () ->
			countdownTimer(".countdown")
			return ""

		shouldShowImages: (step) ->
			if(step <= 1)
				return false
			if(step >= globals.quizTotalSteps - 4)
				return false
			return true


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

	Template.projection.rendered = ->
		if (!this._rendered)
			for filename in globals.conceptimgs_img_filenames
				#js img preloading
				tempimage = new Image()
				tempimage.src = globals.conceptimgs_projection_img_dir + filename
			this._rendered = true;


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


# these functions both on client and server to take advantage of meteor's stub functionality
Meteor.methods
	insertPoint: (data) ->
		pointid = Points.insert data
		if Meteor.isClient
			Session.set('pointid', pointid)
		return pointid

	updateQuizSession: (thisdevice, thisquizstep, thisapidata, thislanguage) ->
		QuizSessions.update(
			{ quizdevice: thisdevice },
			{ $set: { quizStep: thisquizstep, currentApiData: thisapidata, selectedLanguage: thislanguage } },
			{ upsert: true})
		return thisdevice + ":" + thisquizstep


if(Meteor.isServer)
	Meteor.methods
		getClientIp: ->
			return this.connection.clientAddress

		checkApi: (url) ->
				this.unblock();
				return Meteor.http.call("GET", url)



pindropOnBeforeAction = () ->
	$('body').addClass('pindrop')
	theClass = 'pindrop-' + if this.params.quizDevice then 'ipad' else 'default'
	$('body').addClass(theClass)
	# preload will get removed a few seconds after load --
	# so pins loaded on page load are less dramatic than those added
	# live from the quiz
	$('body').addClass('preload')
	this.next()

pindropOnStop = () ->
	$('body').removeClass('pindrop')
	theClass = 'pindrop-' + if this.params.quizDevice then 'ipad' else 'default'
	$('body').removeClass(theClass)
	$('body').removeClass('preload')

Router.map ->

	this.route 'pindropExhibit',
		path: '/pindrop/:quizDevice?',
		layoutTemplate: 'pindrop'
		onBeforeAction: pindropOnBeforeAction
		onStop: pindropOnStop
		data: ->
			return { quizDevice : this.params.quizDevice || 'default' }

	this.route 'pindrop',
		path: '/',
		layoutTemplate: 'pindrop'
		onBeforeAction: pindropOnBeforeAction
		onStop: pindropOnStop

	this.route 'quiz',
		path: '/quiz/:quizDevice?' #question mark makes parameter optional
		layoutTemplate: 'baseTemplate'
		yieldTemplate:
			'quiz': {to: 'quiz'}
		data: ->
			return { quizDevice : this.params.quizDevice || 'default' }
		onBeforeAction: () ->
			$('body').addClass('quiz')
			theClass = 'quiz-' + if this.params.quizDevice && this.params.quizDevice != 'default' then 'ipad' else 'default'
			$('body').addClass(theClass)
			this.next()
		onStop: () ->
			$('body').removeClass('quiz')
			theClass = 'quiz-' + if this.params.quizDevice && this.params.quizDevice != 'default' then 'ipad' else 'default'
			$('body').removeClass(theClass)

	this.route 'projection',
		path: '/projection/:quizDevice'
		layoutTemplate: 'baseTemplate'
		yieldTemplate:
			'projection': {to: 'projection'}
		onBeforeAction: () ->
			$('body').addClass('projection')
			this.next()
		onStop: () ->
			$('body').removeClass('projection')
		data: ->
			return { quizDevice : this.params.quizDevice }
