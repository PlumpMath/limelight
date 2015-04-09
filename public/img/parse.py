# this is a script
# to parse SVGs from Illustrator and return an array of functions (see lib/globals.coffee)
# that we will put into an object back in lib/globals.coffee
# in order to programmatically generate SVGs

from bs4 import BeautifulSoup, Comment
import json

iter = 1

def parseSVG(numString):
    file = open('emoji/' + numString + '.svg', 'r')
    data = file.read()
    svg = BeautifulSoup(data, 'xml')

    output = '['

    parent = svg.find('svg')

    shapes = ['rect', 'polygon', 'circle', 'path']

    for shape in shapes:
        inParent = parent.find_all(shape)
        # only go in if there are shapes
        if len(inParent) > 0:
            for s in inParent:
                # ignore those will a white (#FFFFFF) fill
                if s['fill'] != '#FFFFFF':
                    name = s.name
                    output += name
                    output += '('

                    if name == 'rect':
                        output += s['x'] + ', '
                        output += s['y'] + ', '
                        output += s['width'] + ', '
                        output += s['height']
                    elif name == 'polygon':
                        output += "'" + s['points'] + "'"
                    elif name == 'circle':
                        output += s['cx'] + ', '
                        output += s['cy'] + ', '
                        output += s['r']
                    elif name == 'path':
                        output += "'" + s['d'] + "'"

                    output += '), '

    # trim last two chars
    output = output[0:len(output) - 2]
    # close the array
    output += ']'

    newFile = open('txt/' + numString + '.txt', 'w')
    newFile.write(output)
    newFile.close()

while iter <= 24:
    numString = str(iter).zfill(2)
    parseSVG(numString)
    iter += 1
