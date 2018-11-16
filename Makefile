%.js: %.coffee
	coffee -c $<

all: allfont.js voronoi.js font.js

font.js: allfont.js voronoi.coffee
	coffee voronoi.coffee
