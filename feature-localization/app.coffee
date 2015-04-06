if Meteor.isClient 
	l = (string) ->
		return string.toLocaleString();

	String.toLocaleString(localizations);
	console.log(String.toLocaleString(localizations));
	console.log("yyayayo")



