#!/usr/bin/python
import urllib, json
url = "http://app.designguggenheimhelsinki.org/api/v1/points"
response = urllib.urlopen(url);
data = json.loads(response.read())
print data[0]['quizStepDuration']
print map(lambda x: x['quizStepDuration'] or "", data)

