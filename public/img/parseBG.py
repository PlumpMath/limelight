# this is a script
# to parse SVGs from Illustrator and return an array of functions (see lib/globals.coffee)
# that we will put into an object back in lib/globals.coffee
# in order to programmatically generate SVGs

from bs4 import BeautifulSoup, Comment
from os import listdir

output = '['

def parseSVG(svg):

    global output

    parent = svg.find('svg')

    shapes = ['rect', 'polygon', 'circle', 'path']

    if parent:

        output += '['

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
        output += '], '

for f in listdir('bg'):
    file = open('bg/' + f, 'r')
    data = file.read()
    svg = BeautifulSoup(data, 'xml')
    parseSVG(svg)

output = output[0:len(output) - 2]
output += ']'

newFile = open('bg.txt', 'w')
newFile.write(output)
newFile.close()
