boxWidth = 1
boxHeight = 1

siteRadius = 0.04
siteColor = 'red'
siteDragColor = 'purple'
siteOutsideColor = 'gray'
siteSelectStroke =
  color: '#cccc00'
  width: 0.01
siteDefaultStroke = 'none'
edgeWidth = 0.01
gridStroke =
  color: '#cccccc'
  width: 0.005

if require?
  voronoi = new (require 'voronoi')
else if Voronoi?
  voronoi = new Voronoi

class VoronoiBox
  maxGridLevel: 10

  constructor: (@svg) ->
    @sites = []
    @voronoiEdges = null
    @gridOn = true
    @gridLevel = 2
    @voronoiGroup = @gridGroup = @siteGroup = null

    if @svg?
      @svg.rect boxWidth, boxHeight
      .fill 'white'
      @gridGroup = @svg.group()
      .addClass 'grid'
      @svg.rect boxWidth, boxHeight
      .fill 'none'
      .stroke
        color: 'green'
        width: edgeWidth
      @svg.viewbox
        x: -edgeWidth/2
        y: -edgeWidth/2
        width: boxWidth + edgeWidth
        height: boxHeight + edgeWidth
      @voronoiGroup = @svg.group()
      .addClass 'voronoi'
      @siteGroup = @svg.group()
      .addClass 'sites'

  @fromState: (state, svg) ->
    v = new @ svg
    v.loadState state
    v

  @fromFont: (options, svg) ->
    v = new @ svg
    for key, value of options
      v[key] = value
    v.gridChange()
    v.gridDisplay()
    ## Deep copy to avoid aliasing, messing up original font, etc.
    v.copy v
    v

  copy: (other) ->
    @sites =
      for site in other.sites
        x: site.x
        y: site.y
    @voronoiEdges = other.voronoiEdges
    @siteChange false
    @drawVoronoi()

  loadState: (search = location.search) ->
    if getParameterByName 'grid', search
      @gridLevel = parseInt getParameterByName 'grid', search
      if @gridLevel > @maxGridLevel
        @gridLevel = @maxGridLevel
    @gridChange()
    @gridOn = not getParameterByName 'off', search
    @gridDisplay()
    if getParameterByName 'p', search
      @sites = for p in getParameterByName('p', search).split ';'
        [x, y] = p.split ','
        x: parseFloat x
        y: parseFloat y
    @siteChange()

  gridChange: ->
    return unless @gridGroup?
    @gridGroup.clear()
    n = 2 ** @gridLevel
    for i in [1...n]
      x = i / n
      @gridGroup.line 0, x, boxWidth, x
      .stroke gridStroke
      @gridGroup.line x, 0, x, boxHeight
      .stroke gridStroke

  removeDupSites: (trigger = true) ->
    return  ## not working yet...
    close = siteRadius / 10
    seen = {}
    out = []
    for site in @sites
      if site in @dragSet
        out.push site
      else
        name = Math.round(site.x / close) + ',' + Math.round(site.y / close)
        #console.log name, name of seen
        unless name of seen
          out.push site
          seen[name] = true
    changed = @sites.length != out.length
    @sites = out
    @siteChange() if trigger and changed

  siteChange: (compute = true) ->
    @removeDupSites false
    @drawSites()
    @computeVoronoi() if compute

  drawSites: ->
    return unless @siteGroup?
    @siteGroup.clear()
    for site in @sites
      site.circle = @siteGroup.circle siteRadius
      .center site.x, site.y
      .fill siteColor
      .stroke siteDefaultStroke
    @sites

  hideSites: ->
    return unless @siteGroup?
    @siteGroup.hide()

  computeVoronoi: ->
    diagram = voronoi.compute @sites,
      xl: 0
      xr: boxWidth
      yt: 0
      yb: boxHeight
    @voronoiEdges =
      for edge in diagram.edges
        continue if lineOnEditBox edge.va, edge.vb #onEditBox(edge.va) and onEditBox(edge.vb)
        edge.infinite = onEditBox(edge.va) or onEditBox(edge.vb)
        edge
    @drawVoronoi()

  drawVoronoi: ->
    if @voronoiGroup?
      @voronoiGroup.clear()
      for edge in @voronoiEdges
        # line.stroke
        #   color: 'green'
        #   width: edgeWidth
        line = @voronoiGroup.line edge.va.x, edge.va.y, edge.vb.x, edge.vb.y
        if edge.infinite
          line.addClass 'infinite'
          #line.stroke
          #  color: 'gray'
          #  width: edgeWidth
          #.attr
          #  "stroke-dasharray": "0.01, 0.01"
        #else
        #  line.stroke
        #    color: 'black'
        #    width: edgeWidth
        #  .attr
        #    "stroke-linecap": "round"

  gridToggle: ->
    @gridOn = not @gridOn
    @gridDisplay()

  gridDisplay: ->
    return unless @gridGroup?
    if @gridOn
      @gridGroup.show()
      document.getElementById('grid')?.value = 'Grid Off'
    else
      @gridGroup.hide()
      document.getElementById('grid')?.value = 'Grid On'

class VoronoiEditor extends VoronoiBox
  constructor: (svg) ->
    super svg
    @dragPoint = null
    @dragSet = []
    @alone = false

    @svg.mousedown (e) => @dragnew e
    #@svg.touchstart (e) => @dragnew e
    @svg.mouseup (e) => @dragstop e
    @svg.on 'mouseleave', (e) => @dragstop e
    @svg.touchend touchend = (e) =>
      return unless @dragTouch?
      e.preventDefault()
      e.stopPropagation()
      for touch in e.changedTouches
        if touch.identifier == @dragTouch
          @dragTouch = null
          @dragstop touch
          break
    @svg.touchcancel touchend
    @svg.mousemove (e) => @dragmove e
    @svg.touchmove (e) =>
      return unless @dragTouch?
      e.preventDefault()
      e.stopPropagation()
      for touch in e.changedTouches
        if touch.identifier == @dragTouch
          @dragmove touch
          break
    #@svg.mouseout (e) =>
    #  console.log 'out'
    #  @dragging = null
    @svg.on 'dragstart', (e) =>
      e.preventDefault()
      e.stopPropagation()
    @svg.on 'selectstart', (e) =>
      e.preventDefault()
      e.stopPropagation()
    #document.ontouchstart = (e) =>
    #  e.preventDefault()
    #  e.stopPropagation()
    #document.ontouchmove = (e) =>
    #  e.preventDefault()
    #  e.stopPropagation()

  drawSites: ->
    sites = super()
    return unless sites?
    for site in sites
      do (site) =>
        site.circle
        #.on 'mouseenter', ->
        .mouseover =>
          site.circle.fill siteDragColor
        #.on 'mouseleave', ->
        .mouseout =>
          site.circle.fill siteColor
        .mousedown (e) =>
          e.preventDefault()
          e.stopPropagation()
          @dragclear()
          if e.shiftKey
            @dragSet.push site unless site in @dragSet
          else if e.ctrlKey
            if site in @dragSet
              @dragSet.splice @dragSet.indexOf(site), 1
            else
              @dragSet.push site
          else
            ## Without modifier, still want to drag the set.
            @dragSet = [site] unless site in @dragSet
          @dragstart e
        .touchstart (e) =>
          e.preventDefault()
          e.stopPropagation()
          @dragclear()
          @dragTouch = e.changedTouches[0].identifier
          @dragSet = [site]
          @dragstart e.changedTouches[0]
        #.mouseup (e) ->
        #  unless e.shiftKey or e.ctrlKey
        #    @dragSet = [site]

  screen_pt: (e) ->
    p = @svg.node.createSVGPoint()
    p.x = e.clientX
    p.y = e.clientY
    p.matrixTransform @svg.node.getScreenCTM().inverse()

  dragclear: ->
    @dragPoint = null
    for site in @dragSet
      site.circle?.stroke siteDefaultStroke

  dragstart: (e) ->
    @dragPoint = @screen_pt e
    for site in @dragSet
      site.circle?.stroke siteSelectStroke
      site.startX = site.x
      site.startY = site.y

  dragnew: (e) ->
    e.preventDefault()
    e.stopPropagation()
    return if @dragPoint?
    point = @roundToGrid @screen_pt e
    @sites.push point
    @dragSet = [@sites[@sites.length-1]]
    @dragstart e
    @siteChange()

  dragmove: (e) ->
    e.preventDefault?()
    e.stopPropagation?()
    if @dragPoint?
      point = @screen_pt e
      for site in @dragSet
        #site.x = point.x
        #site.y = point.y
        pos = @roundToGrid
          x: site.startX + point.x - @dragPoint.x
          y: site.startY + point.y - @dragPoint.y
        site.x = pos.x
        site.y = pos.y
        site.circle.center site.x, site.y
        if outsideEditBox site
          site.circle.fill siteOutsideColor
        else
          site.circle.fill siteDragColor
      @computeVoronoi()

  dragstop: (e) ->
    if @dragPoint?
      for site in @dragSet
        site.circle.fill siteColor
      ## Drag outside box to delete a point.
      for site in @dragSet
        if e.type == 'mouseleave' or outsideEditBox site
          @sites.splice @sites.indexOf(site), 1
          @dragSet.splice @dragSet.indexOf(site), 1
          @siteChange()
      @removeDupSites()
      @dragPoint = null
      @saveState()
      e.preventDefault?()
      e.stopPropagation?()

  saveState: ->
    return unless @alone
    siteurl = ("#{site.x},#{site.y}" for site in @sites).join ';'
    history.pushState null, 'voronoi',
      "#{document.location.pathname}?p=#{siteurl}&grid=#{@gridLevel}" +
      if @gridOn then '' else '&off=1'

  roundToGrid: (pt) ->
    return pt unless @gridOn
    n = 2 ** @gridLevel
    x: (Math.round pt.x * n) / n
    y: (Math.round pt.y * n) / n

  gridLess: ->
    if @gridLevel > 1
      @gridLevel -= 1
      @gridChange()
      @saveState()

  gridMore: ->
    if @gridLevel < @maxGridLevel
      @gridLevel += 1
      @gridChange()
      @saveState()

  flipHorizontal: ->
    @sites = for p in @sites
      x: 1-p.x
      y: p.y
    @siteChange()
    @saveState()

  flipVertical: ->
    @sites = for p in @sites
      x: p.x
      y: 1-p.y
    @siteChange()
    @saveState()

  rotateLeft: ->
    @sites = for p in @sites
      x: p.y
      y: -(p.x - 0.5) + 0.5
    @siteChange()
    @saveState()

  rotateRight: ->
    @sites = for p in @sites
      x: -(p.y - 0.5) + 0.5
      y: p.x
    @siteChange()
    @saveState()

  shift: (dx, dy) -> =>
    n = 2 ** @gridLevel
    @sites = for p in @sites
      x: Math.max 0, Math.min 1, p.x + dx / n
      y: Math.max 0, Math.min 1, p.y + dy / n
    @siteChange()
    @saveState()

  computeVoronoi: ->
    super()
    if @linked?
      for link in @linked when link != @
        link.copy @

## Based on jolly.exe's code from http://stackoverflow.com/questions/901115/how-can-i-get-query-string-values-in-javascript
getParameterByName = (name, search = location.search) ->
  name = name.replace /[\[]/g, "\\["
             .replace /[\]]/g, "\\]"
  regex = new RegExp "[\\?&]#{name}=([^&#]*)"
  results = regex.exec search
  return null unless results?
  decodeURIComponent results[1].replace /\+/g, " "

#bboxCorner = (pt) ->
#  (pt.x == 0 or pt.x == boxWidth) and (pt.y == 0 or pt.y == boxHeight)

outsideEditBox = (pt) ->
  pt.x < 0 or pt.x > boxWidth or pt.y < 0 or pt.y > boxHeight

near = (a, b) ->
  Math.abs(a - b) < 0.0000001

onEditBox = (pt) ->
  (near(pt.x, 0) or near(pt.x, boxWidth)) or (near(pt.y, 0) or near(pt.y, boxHeight))

lineOnEditBox = (p, q) ->
  (near(p.x, 0) and near(q.x, 0)) or
  (near(p.x, boxWidth) and near(q.x, boxWidth)) or
  (near(p.y, 0) and near(q.y, 0)) or
  (near(p.y, boxHeight) and near(q.y, boxHeight))

## Based on meouw's answer on http://stackoverflow.com/questions/442404/retrieve-the-position-x-y-of-an-html-element
getOffset = (el) ->
  x = y = 0
  while el and not isNaN(el.offsetLeft) and not isNaN(el.offsetTop)
    x += el.offsetLeft - el.scrollLeft
    y += el.offsetTop - el.scrollTop
    el = el.offsetParent
  x: x
  y: y

resize = (id) ->
  offset = getOffset document.getElementById id
  height = Math.max 100, window.innerHeight - offset.y
  document.getElementById(id).style.height = "#{height}px"

editorGui = ->
  #return unless document.getElementById 'voronoi'
  editor = new VoronoiEditor SVG 'voronoi'
  editor.alone = true

  document.getElementById('grid').addEventListener 'click', -> editor.gridToggle()
  document.getElementById('moreGrid').addEventListener 'click', -> editor.gridMore()
  document.getElementById('lessGrid').addEventListener 'click', -> editor.gridLess()
  document.getElementById('flipHorizontal').addEventListener 'click', -> editor.flipHorizontal()
  document.getElementById('flipVertical').addEventListener 'click', -> editor.flipVertical()
  document.getElementById('rotateLeft').addEventListener 'click', -> editor.rotateLeft()
  document.getElementById('rotateRight').addEventListener 'click', -> editor.rotateRight()
  document.getElementById('shiftLeft').addEventListener 'click', editor.shift -1,0
  document.getElementById('shiftRight').addEventListener 'click', editor.shift +1,0
  document.getElementById('shiftUp').addEventListener 'click', editor.shift 0,-1
  document.getElementById('shiftDown').addEventListener 'click', editor.shift 0,+1

  window.addEventListener 'popstate', -> editor.loadState()
  editor.loadState()
  window.addEventListener 'resize', -> resize 'voronoi'
  resize 'voronoi'

showIt = ->
  hide = getParameterByName 'hide', location.search
  link = document.createElement 'a'
  if hide
    link.setAttribute 'href', '?'
    link.innerText = '[show sites]'
  else
    link.setAttribute 'href', '?hide=1'
    link.innerText = '[hide sites]'
  document.getElementById 'voronoi'
  .appendChild link
  for line in @showMe.split '\n'
    line = line.trim()
    link = line.indexOf 'http://'
    document.getElementById 'voronoi'
    .appendChild(
      if link < 0
        h2 = document.createElement 'h2'
        h2.innerHTML = line
        h2
      else
        url = line[link..]
        label = line[...link].trim()
        box = document.createElement 'div'
        box.className = 'box'
        box.setAttribute 'title', label
        v = VoronoiEditor.fromState url, SVG box
        v.hideSites() if hide
        box
    )

## FONT GUI

radioButtons = [
  options: ['voronoiFont', 'inverseFont']
  default: 'voronoiFont'
,
  options: ['sitesVoronoi', 'sitesOnly', 'voronoiOnly']
  default: 'sitesVoronoi'
]
checkboxes = ['voronoiFont', 'inverseFont', 'sitesVoronoi', 'sitesOnly', 'voronoiOnly', 'grid', 'draggable']
checkboxesRebuild = ['voronoiFont', 'inverseFont', 'draggable']

loadState = ->
  for checkbox in checkboxes
    document.getElementById(checkbox).checked = getParameterByName checkbox
  for radio in radioButtons
    if (true for key in radio.options when document.getElementById(key).checked).length == 0
      document.getElementById(radio.default).checked = true
  text = getParameterByName('text') ? 'text'
  document.getElementById('text').value = text
  updateText false

old = {}
updateText = (setUrl = true, force = false) ->
  params = {}
  params.text = document.getElementById('text').value
    .replace(/\r\n/g, '\r').replace(/\r/g, '\n')
  for checkbox in checkboxes
    params[checkbox] = document.getElementById(checkbox).checked
  classes = []
  classes.push 'hideGrid' unless params.grid
  classes.push 'hideSites' if params.voronoiOnly
  classes.push 'hideVoronoi' if params.sitesOnly
  classes.push 'voronoiFont' if params.voronoiFont
  classes.push 'inverseFont' if params.inverseFont
  document.getElementById('output').setAttribute 'class', classes.join ' '
  size = document.getElementById('size').value
  document.getElementById('svgSize').sheet.deleteRule 0
  document.getElementById('svgSize').sheet.insertRule(
    "svg { width: #{size}px; height: #{size}px }", 0)
  checkParams =
    text: params.text
  for checkbox in checkboxesRebuild
    checkParams[checkbox] = params[checkbox]
  return if (true for key of checkParams when checkParams[key] == old[key]).length == (key for key of checkParams).length and not force
  old = checkParams

  font =
    if params['inverseFont']
      'inverse'
    else
      'voronoi'
  if font == 'voronoi'
    document.getElementById('sitesPuzzle').style.visibility = 'visible'
    document.getElementById('voronoiPuzzle').style.visibility = 'hidden'
  else
    document.getElementById('sitesPuzzle').style.visibility = 'hidden'
    document.getElementById('voronoiPuzzle').style.visibility = 'visible'
  Box =
    if params['draggable']
      VoronoiEditor
    else
      VoronoiBox

  charBoxes = {}
  output = document.getElementById 'output'
  output.innerHTML = '' ## clear previous children
  for line in params.text.split '\n'
    output.appendChild outputLine = document.createElement 'p'
    outputLine.setAttribute 'class', 'line'
    outputLine.appendChild outputWord = document.createElement 'span'
    outputWord.setAttribute 'class', 'word'
    for char, c in line
      char = char.toUpperCase()
      if char of window.fonts[font]
        letter = window.fonts[font][char]
        svg = SVG outputWord
        box = Box.fromFont letter, svg
        charBoxes[char] ?= []
        charBoxes[char].push box
        box.linked = charBoxes[char]
      else if char == ' '
        #space = document.createElement 'span'
        #space.setAttribute 'class', 'space'
        #outputLine.appendChild space
        outputLine.appendChild outputWord = document.createElement 'span'
        outputWord.setAttribute 'class', 'word'
      else
        console.log "Unknown character '#{char}'"

  if setUrl
    encoded =
      for key, value of params
        if value == true
          value = '1'
        else if value == false
          continue
        key + '=' + encodeURIComponent(value).replace /%20/g, '+'
    history.pushState null, 'text',
      "#{document.location.pathname}?#{encoded.join '&'}"

fontResize = ->
  document.getElementById('size').max =
    document.getElementById('size').scrollWidth - 30 - 2
                                              # - circle width - border width

fontGui = ->
  updateTextSoon = (event) ->
    setTimeout updateText, 0
    true
  for event in ['input', 'propertychange', 'keyup']
    document.getElementById('text').addEventListener event, updateTextSoon
  for event in ['input', 'propertychange', 'click']
    for checkbox in checkboxes
      document.getElementById(checkbox).addEventListener event, updateTextSoon
  for event in ['input', 'propertychange', 'click']
    document.getElementById('size').addEventListener event, updateTextSoon
  document.getElementById('reset').addEventListener 'click', ->
    updateText false, true

  window.addEventListener 'popstate', loadState
  loadState()
  window.addEventListener 'resize', fontResize
  fontResize()

  for font in ['voronoi', 'inverse']
    document.getElementById("#{font}Links").innerHTML = (
      for char in (key for key of window.fonts[font]).sort()
        """<A HREF="#{window.fonts[font][char].url}">#{char}</A>"""
    ).join ", "

## GUI MAIN

window?.onload = ->
  if @showMe
    showIt()
  else if window.fonts
    fontGui()
  else if document.getElementById('voronoi')?
    editorGui()

## FONT PRECOMPUTATION

main = ->
  showMe = require('./allfont').showMe
  fonts =
    voronoi: {}
    inverse: {}
  currentFont = ''
  for line in showMe.split '\n'
    line = line.trim()
    switch line
      when 'FONT'
        currentFont = 'voronoi'
      when 'Backwards Voronoi'
        currentFont = 'inverse'
      else
        link = line.indexOf 'http://'
        continue if link < 0
        url = line[link..]
        label = line[...link].trim()
        continue if label.length != 1  ## single character is final font
        v = VoronoiBox.fromState url
        fonts[currentFont][label] =
          sites: v.sites[..]
          voronoiEdges: v.voronoiEdges
          gridLevel: v.gridLevel
          url: url

  fs = require 'fs'
  stringify = require 'json-stringify-pretty-compact'
  fs.writeFileSync 'font.js', """
    window.fonts = #{stringify(fonts).replace /, "voronoiId": \d+/g, ''};
  """

main() if require? and require.main == module
