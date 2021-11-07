boxWidth = 1
boxHeight = 1

siteRadius = 0.04
edgeWidth = 0.01  # also in voronoi.styl

if require?
  voronoi = new (require 'voronoi')
else if Voronoi?
  voronoi = new Voronoi

class VoronoiBox
  maxGridLevel: 10

  constructor: (@svg, @colorCells) ->
    @sites = []
    @voronoiEdges = null
    @gridOn = true
    @gridLevel = 2
    @vcellGroup = @vedgeGroup = @gridGroup = @siteGroup = null
    @width = boxWidth
    @height = boxHeight

    if @svg?
      @bg = @svg.rect()
      .addClass 'bg'
      @vcellGroup = @svg.group()
      .addClass 'vcell'
      @gridGroup = @svg.group()
      .addClass 'grid'
      @outline = @svg.rect()
      .addClass 'outline'
      @vedgeGroup = @svg.group()
      .addClass 'vedge'
      @siteGroup = @svg.group()
      .addClass 'sites'
      @sizeChange()

  @fromState: (state, svg, colorCells) ->
    v = new @ svg, colorCells
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

  sizeChange: ->
    for rect in [@bg, @outline]
      rect.size @width, @height
    @svg.viewbox
      x: -edgeWidth/2
      y: -edgeWidth/2
      width: @width + edgeWidth
      height: @height + edgeWidth
    @gridChange()

  gridChange: ->
    return unless @gridGroup?
    @gridGroup.clear()
    n = 2 ** @gridLevel
    for i in [1...n * @width]
      x = i / n
      @gridGroup.line x, 0, x, @height
    for i in [1...n * @height]
      y = i / n
      @gridGroup.line 0, y, @width, y

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
    @sites

  hideSites: ->
    return unless @siteGroup?
    @siteGroup.hide()

  computeVoronoi: ->
    diagram = voronoi.compute @sites,
      xl: 0
      xr: @width
      yt: 0
      yb: @height
    @voronoiEdges =
      for edge in diagram.edges
        continue if @lineOnEditBox edge.va, edge.vb #@onEditBox(edge.va) and @onEditBox(edge.vb)
        edge.infinite = @onEditBox(edge.va) or @onEditBox(edge.vb)
        delete edge.lSite
        delete edge.rSite
        edge
    if @colorCells
      @voronoiCells =
        for cell in diagram.cells
          continue if cell.halfedges.length < 2
          for halfedge, i in cell.halfedges
            ## Sadly, getStartpoint() seems to get the wrong order.
            #halfedge.getStartpoint()
            if i == 0
              ## Start with the vertex shared with the next edge
              next = cell.halfedges[1].edge
              if halfedge.edge.va in [next.va, next.vb]
                last = halfedge.edge.va
              else
                last = halfedge.edge.vb
            else
              ## Continue with the vertex not shared with the previous edge.
              ## Handle near-identical vertices in addition to identical.
              if last == halfedge.edge.va
                last = halfedge.edge.vb
              else if last == halfedge.edge.vb
                last = halfedge.edge.va
              else
                da = distanceSquared last, halfedge.edge.va
                db = distanceSquared last, halfedge.edge.vb
                if da < db
                  last = halfedge.edge.vb
                else
                  last = halfedge.edge.va
    @drawVoronoi()

  drawVoronoi: ->
    if @vcellGroup?
      @vcellGroup.clear()
      if @colorCells
        for cell in @voronoiCells
          @vcellGroup.polygon ("#{v.x},#{v.y}" for v in cell).join ' '
          .fill @colorCells()
    if @vedgeGroup?
      @vedgeGroup.clear()
      for edge in @voronoiEdges
        line = @vedgeGroup.line edge.va.x, edge.va.y, edge.vb.x, edge.vb.y
        line.addClass 'infinite' if edge.infinite

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

  outsideEditBox: (pt) ->
    pt.x < 0 or pt.x > @width or pt.y < 0 or pt.y > @height

  onEditBox: (pt) ->
    (near(pt.x, 0) or near(pt.x, @width)) or (near(pt.y, 0) or near(pt.y, @height))

  lineOnEditBox: (p, q) ->
    (near(p.x, 0) and near(q.x, 0)) or
    (near(p.x, @width) and near(q.x, @width)) or
    (near(p.y, 0) and near(q.y, 0)) or
    (near(p.y, @height) and near(q.y, @height))

class VoronoiEditor extends VoronoiBox
  constructor: (...args) ->
    super ...args
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
    @svg.point e.clientX, e.clientY

  dragclear: ->
    @dragPoint = null
    for site in @dragSet
      site.circle?.removeClass 'select'

  dragstart: (e) ->
    @dragPoint = @screen_pt e
    for site in @dragSet
      site.circle?.addClass 'select'
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
        if @outsideEditBox site
          site.circle.addClass 'outside'
        else
          site.circle.removeClass 'outside'
      @computeVoronoi()

  dragstop: (e) ->
    if @dragPoint?
      for site in @dragSet
        site.circle.removeClass 'drag'
      ## Drag outside box to delete a point.
      for site in @dragSet
        if e.type == 'mouseleave' or @outsideEditBox site
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

near = (a, b) ->
  Math.abs(a - b) < 0.0000001
distanceSquared = (v1, v2) ->
  dx = v1.x - v2.x
  dy = v1.y - v2.y
  dx * dx + dy * dy

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
  editor = new VoronoiEditor SVG().addTo '#voronoi'
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
        v = VoronoiEditor.fromState url, SVG().addTo box
        v.hideSites() if hide
        box
    )

## FONT GUI

Box = (state, svg) ->
  if state.draggable
    VoronoiEditor
  else
    VoronoiBox
hue = saturation = lightness = null  # sliders
colorBox = (state) ->
  if state.color
    ->
      hues = (parseFloat(x) for x in hue.get())
      saturations = (parseFloat(x) for x in saturation.get())
      lightnesses = (parseFloat(x) for x in lightness.get())
      "hsl(#{Math.random()*(hues[1]-hues[0])+hues[0]},#{Math.random()*(saturations[1]-saturations[0])+saturations[0]}%,#{Math.random()*(lightnesses[1]-lightnesses[0])+lightnesses[0]}%)" 

if window?.fonts?
  fontGridLevel = 0
  for fontName, fontLetters of window.fonts
    fontGridLevel = Math.max fontGridLevel,
      ...(fontLetter.gridLevel for fontChar, fontLetter of fontLetters)
if FontWebapp?
  class FontWebappVoronoi extends FontWebapp
    initDOM: ->
      @svg = SVG().addTo @root
    render: (state = @furls.getState()) ->
      @svg.clear()
      #@box?.destroy()
      @box = new (Box state) @svg, colorBox state
      @box.gridLevel = fontGridLevel
      y = 0
      xmax = 0
      for line in state.text.split '\n'
        x = 0
        dy = 0
        for char, c in line
          if char == ' ' and @options.spaceWidth?
            x += @options.spaceWidth
          else
            x += @options.charKern unless c == 0 if @options.charKern?
            if (glyph = @options.renderChar.call @, char, state, @box, x, y)?
              x += glyph.width
            else
              console.warn "Unrecognized character '#{char}'"
            xmax = Math.max xmax, x
            dy = Math.max dy, glyph.height
        y += dy + (@options.lineKern ? 0)
      @box.width = xmax
      @box.height = y
      @box.sizeChange()
      @box.siteChange()
      margin = @options.margin ? 0
      @svg.viewbox
        x: -margin
        y: -margin
        width: xmax + 2*margin
        height: y + 2*margin
    destroy: ->
      super()
      @svg.clear().remove()
    downloadSVG: FontWebappSVG::downloadSVG

fontGui = ->
  ## Convert old URL format (pre-furls) to new format
  search = window.location.search
  search = search
  .replace /inverseFont=1/g, 'font=inverse'
  .replace /voronoiFont=1/g, 'font=voronoi'
  .replace /sitesVoronoi=1/g, 'show=both'
  .replace /sitesOnly=1/g, 'show=sites'
  .replace /voronoiOnly=1/g, 'show=voronoi'
  window.location.search = search unless window.location.search == search

  ## H/S/L sliders
  sliderOptions =
    connect: true
    tooltips: true
    orientation: 'vertical'
    format:
      from: Math.round
      to: Math.round
  hue = noUiSlider.create document.getElementById('hue'),
    Object.assign {}, sliderOptions,
      range:
        min: 0
        max: 360
      start: [0, 360]
  saturation = noUiSlider.create document.getElementById('saturation'),
    Object.assign {}, sliderOptions,
      range:
        min: 0
        max: 100
      start: [50, 100]
  lightness = noUiSlider.create document.getElementById('lightness'),
    Object.assign {}, sliderOptions,
      range:
        min: 0
        max: 100
      start: [25, 75]
  for slider in [hue, saturation, lightness]
    slider.on 'set', ->
      if app.box?  ## In one-diagram mode, redraw insteade of recompute
        app.box.drawVoronoi()
      else
        app.render()

  app = null
  launch = (changed) ->
    return unless changed.one
    state = furls.getState()
    app?.destroy()
    common =
      furls: furls
      root: '#output'
      shouldRender: (changed) ->
        changed.text or changed.font or changed.draggable or changed.color
    if state.one
      app = new FontWebappVoronoi Object.assign common,
        spaceWidth: boxWidth / 4
        renderChar: (char, state, box, x, y) ->
          font = state.font
          char = char.toUpperCase()
          letter = window.fonts[font][char]
          return unless letter?
          for site in letter.sites
            box.sites.push
              x: site.x + x
              y: site.y + y
          width: boxWidth
          height: boxHeight
    else
      app = new FontWebappHTML Object.assign common,
        sizeSlider: '#size'
        charWidth: 200
        charPadding: 0
        lineKern: 32
        spaceWidth: 50
        renderChar: (char, state, parent) ->
          font = state.font
          char = char.toUpperCase()
          letter = window.fonts[font][char]
          return unless letter?
          options = Object.assign colorCells: colorBox(state), letter
          Box(state).fromFont options, SVG().addTo parent
        linkIdenticalChars: (glyphs) ->
          glyph.linked = glyphs for glyph in glyphs
  furls = new Furls()
  .addInputs()
  .syncState()
  .syncClass()
  .on 'stateChange', launch
  launch one: true

  document.getElementById('reset').addEventListener 'click', -> app.render()

  document.querySelector('#downloadSVG button').addEventListener 'click', ->
    copy = app.svg.clone()
    copy.addTo 'body'
    ## Add CSS
    copy.element 'style'
    .words document.getElementById('svgStyle').innerHTML
    ## Remove groups set to display: none because of class options
    ## (which won't be in the SVG).
    copy.find 'g'
    .each (g) ->
      g.remove() if window.getComputedStyle(g.node).display == 'none'
    app.downloadSVG 'voronoi.svg', copy.svg()
    copy.remove()

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
  showMe = require('./allfont.coffee').showMe
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
        v = VoronoiBox.fromState url, undefined, true
        fonts[currentFont][label] =
          sites: v.sites[..]
          voronoiEdges: v.voronoiEdges
          voronoiCells: v.voronoiCells
          gridLevel: v.gridLevel
          url: url

  fs = require 'fs'
  stringify = require 'json-stringify-pretty-compact'
  fs.writeFileSync 'font.js', """
    window.fonts = #{stringify(fonts).replace /, "voronoiId": \d+/g, ''};
  """

main() if require? and require.main == module
