'use strict'

###*
 # @ngdoc function
 # @name edudashApp.controller:DashboardsCtrl
 # @description
 # # DashboardsCtrl
 # Controller of the edudashApp
###
angular.module('edudashAppCtrl').controller 'DashboardCtrl', [
    '$scope', '$window', '$routeParams', '$anchorScroll', '$http', 'leafletData',
    '_', '$q', 'WorldBankApi', 'layersSrv', '$log','$location','$translate',
    '$timeout', 'colorSrv', 'OpenDataApi', 'loadingSrv', 'topojson',
    'staticApi', 'watchComputeSrv', 'bracketsSrv', 'utils'

    ($scope, $window, $routeParams, $anchorScroll, $http, leafletData,
    _, $q, WorldBankApi, layersSrv, $log, $location, $translate,
    $timeout, colorSrv, OpenDataApi, loadingSrv, topojson,
    staticApi, watchComputeSrv, brackets, utils) ->

        # other state
        layers = {}
        currentLayer = null

        #### Template / Controller API via $scope ####

        # app state
        angular.extend $scope,
          year: null  # set after init
          years: null
          yearAggregates: null
          metric: null
          sortMetric:  null
          viewMode: null  # set after init
          schoolType: $routeParams.type
          polyType: null
          hovered: null
          lastHovered: null
          selectedCode: null
          selected: null
          selectedLayer: null
          allSchools: null
          filteredSchools: null
          pins: null
          rankBy: null  # performance or improvement for primary
          rankedBy: null
          moreThan40: null  # students, for secondary schools
          polygons: null
          detailedPolys: null
          polyLayer: null
          filterPassRateP: # To be used in primary school view 
            range: {
              min: 0,
              max: 100
            },
            minValue: 0,
            maxValue: 100
           filterPassRateS: # To be used in secondary school view 
            range: {
              min: 0,
              max: 10
            },
            minValue: 0,
            maxValue: 10,

        # state transitioners
        angular.extend $scope,
          setYear: (newYear) -> $scope.year = newYear
          setViewMode: (newMode) -> $scope.viewMode = newMode
          setVisMode: (newMode) -> $scope.visMode = newMode
          setSchoolType: (newType) -> $location.path "/dashboard/#{newType}/"
          togglePolygons: (polyType) -> togglePolygons polyType
          hover: (id) -> hoverThing id
          keepHovered: -> $scope.hovered = $scope.lastHovered
          unHover: -> $scope.hovered = null
          select: (code) -> $scope.selectedCode = code
          search: (q) -> search q
          hasBadge: (b, st, v) -> brackets.hasBadge b, st, v
          getBracket: (v, m) -> brackets.getBracket v, (m or $scope.visMetric)
          getColor: (v, m) -> colorSrv.color $scope.getBracket v, m
          getArrow: (v, m) -> colorSrv.arrow $scope.getBracket v, m

        # view util functions
        angular.extend $scope,
          Math: Math


        watchCompute = watchComputeSrv $scope

        watchCompute 'visMetric',
          dependencies: ['visMode']
          computer: ([visMode]) ->
            brackets.getVisMetric visMode

        watchCompute 'sortMetric',
          dependencies: ['schoolType', 'rankBy']
          computer: ([schoolType, criteria]) ->
            unless schoolType? and criteria?
              null
            else
              brackets.getSortMetric schoolType, criteria

        watchCompute 'allSchools',
          dependencies: ['viewMode', 'year', 'schoolType', 'rankBy', 'moreThan40']
          computer: ([viewMode, year, rest...]) ->
            if year? then loadSchools viewMode, year, rest...
            else
              null

        watchCompute 'polygons',
          dependencies: ['viewMode', 'polyType']
          computer: ([viewMode, polyType]) ->
            unless viewMode == 'polygons'
              null
            else
              switch polyType
                when 'regions' then loadRegions()
                when 'districts' then loadDistricts()
                else (
                  $log.warn "unknown polyType '#{polyType}'"
                  null
                )

        watchCompute 'detailedPolys',
          dependencies: ['polygons', 'allSchools', 'polyType', 'schoolType']
          waitForPromise: true
          computer: ([polygons, allSchools, polyType, schoolType], [oldPolys, oldSchools]) ->
            $q (resolve, reject) ->
              unless polygons? and allSchools? and (polygons != oldPolys or allSchools != oldSchools)
                resolve null
              else
                $q.all
                    polys: polygons
                    schools: allSchools
                  .then ({polys, schools}) ->
                    detailsByPoly = getDetailsByPoly schools, polyType, schoolType
                    resolve polys.map (poly) ->
                      # TODO: warn about polys mismatch
                      properties = angular.extend detailsByPoly[poly.id] or {},
                        NAME: poly.id
                      angular.extend poly, properties: properties

                  .catch reject

        # When we get per-school pupil-teacher ratio data, we can compute this client-side
        watchCompute 'pupilTeacherRatio',
          dependencies: ['allSchools']
          waitForPromise: true
          computer: ([allSchools]) ->
            $q (resolve, reject) ->
              if allSchools?
                allSchools.then (data) ->
                  total = _(data).reduce ((memo, school) ->
                    memo + school.PUPIL_TEACHER_RATIO
                  ), 0
                  resolve if isNaN(total) then null else total/data.length
              else
                resolve null

        watchCompute 'yearAggregates',
          dependencies: ['schoolType', 'rankBy', 'moreThan40'],
          waitForPromise: true,
          computer: ([schoolType, rankBy, moreThan40]) -> $q (resolve, reject) ->
            OpenDataApi.getYearAggregates schoolType, rankBy, moreThan40
              .then (years) ->
                resolve _(years).reduce ((agg, y) ->
                  agg[y.YEAR_OF_RESULT] =
                    PASS_RATE: y.average_pass_rate
                    color: colorSrv.color brackets.getBracket y.average_pass_rate, 'PASS_RATE'
                  agg
                ), {}
              .catch reject

        watchCompute 'schoolCodeMap',
          dependencies: ['viewMode', 'allSchools']
          waitForPromise: true  # unwraps the promise
          computer: ([viewMode, allSchools]) -> $q (resolve, reject) ->
            unless viewMode == 'schools' and allSchools?
              resolve null
            else
              allSchools
                .then (basics) ->
                  resolve _(basics).reduce ((byCode, s) ->
                    byCode[s.CODE] = s
                    byCode
                  ), {}
                .catch reject

        watchCompute 'polyIdMap',
          dependencies: ['detailedPolys']
          computer: ([polygons]) ->
            unless polygons?
              null
            else
              polygons.reduce ((map, polygon) ->
                map[polygon.id] = polygon
                map
              ), {}

        watchCompute 'rankedBy',
          dependencies: ['viewMode', 'allSchools', 'rankBy', 'schoolCodeMap']
          computer: ([viewMode, allSchools, rankBy, map]) ->
            unless viewMode == 'schools' and allSchools? and map?
              null
            else
              $q (resolve, reject) ->
                allSchools.then ((schools) ->
                  resolve rankSchools schools, $scope.sortMetric
                ), reject

        watchCompute 'filteredSchools',
          dependencies: ['viewMode', 'allSchools']
          computer: ([viewMode, allSchools]) ->
            unless viewMode == 'schools' and allSchools?
              null
            else
              $q (res, x) -> allSchools.then res, x

        watchCompute 'pins',
          dependencies: ['filteredSchools', 'year', 'schoolType', 'moreThan40']
          waitForPromise: true
          computer: ([schoolsP, year, schoolType, moreThan40], [oldSchoolsP]) ->
            $q (resolve, reject) ->
              # Only continue when we have a new promise for the schools.
              # year, schoolType. etc. are dependencies because we need them
              # for the layerId, but they can sometimes trigger before we have
              # an up-to-date promise for the schools themselves.
              unless schoolsP? and schoolsP != oldSchoolsP
                resolve null
              else
                layerId = "schools-#{year}-#{schoolType}-#{moreThan40}"
                schoolsP.then ((schools) ->
                  resolve layersSrv.addFastCircles layerId, mapId,
                    getData: -> $q (res, rej) ->
                      map = (data) -> if data?
                        res data.map (s) -> [ s.LATITUDE, s.LONGITUDE, s.CODE ]
                      schoolsP.then map, rej
                    options:
                      className: 'school-location'
                      radius: 8
                      onEachFeature: processPin
                ), reject

        watchCompute 'polyLayer',
          dependencies: ['detailedPolys', 'polyType']
          waitForPromise: true
          computer: ([polys, polyType], [oldPolys]) -> $q (resolve, reject) ->
            unless polys? and polys != oldPolys
              resolve null
            else
              layerId = "polygons-#{polyType}"
              resolve layersSrv.addGeojsonLayer layerId, mapId,
                getData: -> $q.when
                  type: 'FeatureCollection'
                  features: polys
                options: onEachFeature: processPoly

        watchCompute 'lastHovered',
          dependencies: ['hovered']
          computer: ([thing], [oldThing]) -> thing or oldThing

        watchCompute 'selected',
          dependencies: ['selectedCode', 'viewMode', 'allSchools']
          waitForPromise: true
          computer: ([code, viewMode, allSchools]) ->
            unless code?
              $q.when null
            else switch viewMode
              when 'schools' then findSchool code
              when 'polygons' then findPoly code
              else $q (resolve, reject) -> reject "Unknown viewMode: '#{viewMode}'"

        watchCompute 'selectedLayer',
          dependencies: ['selectedCode', 'selected', 'viewMode']
          computer: ([code, thing, viewMode]) ->
            unless code? and thing?
              null
            else switch viewMode
              when 'schools' then (
                latlng = [thing.LATITUDE, thing.LONGITUDE]
                # note that layerSrv.marker is cached by the id provided ('school-marker')
                layer = layersSrv.marker 'school-marker', mapId,
                  latlng: latlng
                  options: icon: layersSrv.awesomeIcon
                    markerColor: 'blue'
                    icon: 'map-marker'
                # so we have to reset the latlng for subsequent times
                layer.then (l) -> l.setLatLng latlng
                layer
              )
              when 'polygons' then (
                layerId = "poly-marker-#{thing.id}"
                layer = layersSrv.addGeojsonLayer layerId, mapId,
                  getData: -> $q.when thing
                  options: onEachFeature: (feature, layer) ->
                    colorPoly feature, layer
                    layer.setStyle colorSrv.polygonSelect()
                layer
              )
              else throw new Error 'blah blah blah'

        # side-effects only
        $scope.$watch 'allSchools', (schoolsP) -> if schoolsP?
          loadingSrv.containerLoad schoolsP, document.getElementById mapId
          schoolsP.then (schools) ->
            if $scope.selected? and $scope.viewMode == 'schools'
              $scope.selectedCodeYear =  # TODO: fix issue with 'selected' watchCompute and remove this assignment
                code: $scope.selected.CODE
                year: $scope.year
              $scope.select $scope.selected.CODE

        # TODO: fix issue with 'selected' watchCompute and remove this entire $watch
        $scope.$watch 'selectedCodeYear', (selectedCodeYear) -> if selectedCodeYear?
          (findSchool selectedCodeYear.code).then (school)->
            $scope.selected = school

        # side-effect: map spinner for polygons load
        $scope.$watch 'polygons', (polysP) -> if polysP?
          loadingSrv.containerLoad polysP, document.getElementById mapId

        # side-effects only
        $scope.$watch 'pins', (blah, oldPins) -> if oldPins?
          leafletData.getMap(mapId).then (map) -> map.removeLayer oldPins

        # side-effects only
        $scope.$watch 'polyLayer', (newPolys, oldPolys) -> if oldPolys?
          leafletData.getMap(mapId).then (map) -> map.removeLayer oldPolys

        # side-effect: ensure that a selectedLayer is always in front, if exists
        $scope.$watch 'polyLayer', -> if $scope.selectedLayer?
          $scope.selectedLayer.then (l) -> l.bringToFront()

        # side-effect: clear selectedLayer sometimes
        $scope.$watch 'polyType', (newType, oldType) ->
          unless newType?
            $scope.select null
          else
            if oldType == 'districts'
              $scope.select null

        # side-effect: remove old selected layer
        $scope.$watch 'selectedLayer', (newL, oldLayer) -> if oldLayer?
          $q.all
              map: leafletData.getMap(mapId)
              layer: oldLayer
            .then ({map, layer}) -> map.removeLayer layer

        # side-effect: zoom in to selected polyLayer
        $scope.$watch 'selectedLayer', (newL) -> if newL?
          if $scope.viewMode == 'polygons'
            $q.all
                map: leafletData.getMap(mapId)
                layer: newL
              .then ({map, layer}) ->
                map.fitBounds layer.getBounds()
            if $scope.polyType = 'regions'
              # clicked a region -- switch to districts mode
              $scope.polyType = 'districts'

        # side-effects only
        $scope.$watchGroup ['pins', 'visMode'], ([pins]) -> if pins?
          pins.eachVisibleLayer colorPin

        # side-effects: zoom to bounds if nothing selected
        $scope.$watch 'polyLayer', (polyLayer) -> if polyLayer?
          unless $scope.selectedLayer?
            leafletData.getMap mapId
              .then (map) -> map.fitBounds polyLayer.getBounds()

        # side-effects only
        $scope.$watchGroup ['polyLayer', 'polyIdMap'],
          ([polyLayer, polyIdMap]) ->
            if polyLayer? and polyIdMap?
              polyLayer.eachLayer (layer) ->
                feature = polyIdMap[layer.feature.id]
                if feature?
                  colorPoly feature, layer

        # side-effects only
        $scope.$watch 'viewMode', (newMode, oldMode) ->
          if newMode not in ['schools', 'polygons']
            console.error 'changed to invalid view mode:', newMode
            return
          # unless newMode == oldMode  # doesnt work for initial render
          leafletData.getMap(mapId).then (map) ->
            unless currentLayer == null
              map.removeLayer currentLayer
              currentLayer = null

        # side-effects only
        $scope.$watch 'hovered', (thing, oldThing) ->
          if thing != null
            switch $scope.viewMode
              when 'schools' then getSchoolPin(thing.CODE).then (pin) ->
                pin.bringToFront()
                pin.setStyle colorSrv.pinOn()
              when 'polygons' then getPolyLayer(thing.id).then (layer) ->
                layer.bringToFront()
                layer.setStyle colorSrv.polygonOn()
                if $scope.selectedLayer?  # never go in front of a selected layer
                  $scope.selectedLayer.then (l) -> l.bringToFront()
                rankPoly thing

          if oldThing != null
            switch $scope.viewMode
              when 'schools' then getSchoolPin(oldThing.CODE).then (pin) ->
                pin.setStyle colorSrv.pinOff()
              when 'polygons' then getPolyLayer(oldThing.id).then (layer) ->
                layer.setStyle colorSrv.polygonOff()

        # side-effects only
        $scope.$watch 'selected', (thing) -> if thing?
          if $scope.viewMode == 'schools'
            setSchool thing
          else if $scope.viewMode == 'polygons'
            # pass
          else
            $log.warn "Unknown viewMode to update selected: '#{$scope.viewMode}'"

        $scope.$on 'filtersToggle', (event, opts) ->
          $scope.filtersHeight = opts.height

        loadSchools = (viewMode, year, schoolType, rankBy, moreThan40) ->
          OpenDataApi.getSchools
            year: year
            schoolType: schoolType
            subtype: rankBy
            moreThan40: moreThan40

        loadRegions = ->
          $q (resolve, reject) ->
            staticApi.getRegions()
              .then (topo) ->
                {features} = topojson.feature topo, topo.objects.tz_Regions
                resolve features.map (feature) ->
                  type: feature.type
                  id: feature.properties.name.toUpperCase()
                  geometry: feature.geometry
              .catch reject

        loadDistricts = ->
          $q (resolve, reject) ->
            staticApi.getDistricts()
              .then (topo) ->
                {features} = topojson.feature topo, topo.objects.tz_districts
                resolve features.map (feature) ->
                  type: feature.type
                  id: feature.properties.name.toUpperCase()
                  geometry: feature.geometry
              .catch reject

        togglePolygons = (polyType) ->
          unless $scope.viewMode == 'polygons' and $scope.polyType == polyType
            $scope.polyType = polyType
            $scope.setViewMode 'polygons'
          else  # un-toggle
            $scope.polyType = null
            $scope.setViewMode 'schools'

        hoverThing = (id) ->
          if $scope.viewMode == 'schools'
            findSchool id
              .then (s) -> $scope.hovered = s
              .catch $log.error
          else if $scope.viewMode == 'polygons'
            findPoly id
              .then (r) -> $scope.hovered = r
              .catch $log.error

        setSchool = (school) ->
          latlng = [school.LATITUDE, school.LONGITUDE]
          leafletData.getMap(mapId).then (map) ->
            map.setView latlng, (Math.max 9, map.getZoom())
          [ob, desc] = brackets.getRank $scope.schoolType
          unless school.ranks?
            $q.all
                national: (rank school, 'NATIONAL', [ob, desc])
                region: (rank school, 'REGION', [ob, desc])
                district: (rank school, 'DISTRICT', [ob, desc])
              .then (ranks) ->
                school.ranks = ranks

          unless school.yearAggregates?
            OpenDataApi.getSchoolAggregates $scope.schoolType, $scope.rankBy, school.CODE
              .then (data) ->
                school.yearAggregates =
                  values: _(data).reduce ((agg, year) ->
                    agg[year.YEAR_OF_RESULT] =
                      PASS_RATE: year.PASS_RATE
                      color: colorSrv.color brackets.getBracket year.PASS_RATE, 'PASS_RATE'
                    agg
                  ), {}
                  years: $scope.years
                thisYear = school.yearAggregates.values[$scope.year]
                lastYear = school.yearAggregates.values[$scope.year - 1]
                if lastYear?
                  school.CHANGE_PREVIOUS_YEAR_PASSRATE = thisYear.PASS_RATE - lastYear.PASS_RATE
                # else undefined

        findSchool = (code) ->
          $q (resolve, reject) ->
            if $scope.allSchools? and $scope.schoolCodeMap?
              findIt = (schools) ->
                if $scope.schoolCodeMap[code]?
                  resolve $scope.schoolCodeMap[code]
                else
                  reject "Could not find school by code '#{code}'"
              $scope.allSchools.then findIt, reject
            else
              reject 'No schools to find from'

        findPoly = (id) ->
          $q (resolve, reject) ->
            if $scope.polyIdMap?
              if $scope.polyIdMap[id]?
                resolve $scope.polyIdMap[id]
              else
                reject "Could not find polygon by id '#{id}'"
            else
              reject 'No polygons to find from'

        # side-effect: mutates poly (gross, but...)
        rankPoly = (poly) ->
          p = poly.properties
          ps = $scope.detailedPolys.map (p) -> p.properties
          poly.properties.ranks = NATIONAL: utils.rank p, ps, 'PASS_RATE'
          if $scope.polyType == 'districts'
            poly.properties.ranks.REGIONAL = utils.rank p, ps, 'PASS_RATE', 'REGION'

        getSchoolPin = (code) -> $q (resolve, reject) ->
          layer = $scope.pins.getLayer code
          if layer?
            resolve layer
          else
            reject "No pin found for school code #{code}"

        getPolyLayer = (id) -> $q (resolve, reject) ->
          unless $scope.polyLayer?
            reject 'No polygon layers to find from'
          else
            layer = null
            $scope.polyLayer.eachLayer (l) ->
              if l.feature.id == id
                if layer?
                  $log.warn "Multiple layers found for id #{id}"
                layer = l
            unless layer?
              reject "No polygon layer found for '#{id}'"
            else
              resolve layer

        # get the (rank, total) of a school, filtered by its region or district or national
        rank = (school, rank_by, [ob, desc]) ->
          grouper = switch rank_by
            when 'REGION', 'DISTRICT' then rank_by
            when 'NATIONAL' then null
            else throw new Error "invalid rank_by: '#{rank_by}'"
          $q (resolve, reject) ->
            rankSchool = (schools) ->
              try
                resolve utils.rank school, schools, ob, grouper, if desc then 'DESC' else 'ASC'
              catch err
                reject err
            $scope.allSchools.then rankSchool, reject

        rankSchools = (schools, [orderBy, desc]) ->
          ob = orderBy
          if ob not in ['CHANGE_PREVIOUS_YEAR',
                        'RANK',
                        'PASS_RATE',
                        'AVG_GPA',
                        'CHANGE_PREVIOUS_YEAR_GPA',
                        'AVG_MARK' ]
            throw new Error "invalid orderBy: '#{ob}'"
          _.unique(schools
            .filter (s) -> s[ob]?
              .sort (a, b) -> if desc then b[ob] - a[ob] else a[ob] - b[ob]
          )


        # widget local state (maybe should move to other directives)
        $scope.searchText = "dar"
        $scope.schoolsChoices = []

        # controller constants
        mapId = 'map'

        if $routeParams.type isnt 'primary' and $routeParams.type isnt 'secondary'
          $timeout -> $location.path '/'

        # INIT
        leafletData.getMap(mapId).then (map) ->
          # initialize the map view
          map.fitBounds [[-.8, 29.3], [-11.8, 40.8]]
          # add the basemap
          layersSrv.addTileLayer 'gray', mapId,
            url: '//api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}',
            id: 'worldbank-education.map-5e5fgg2o'
            accessToken: 'pk.eyJ1Ijoid29ybGRiYW5rLWVkdWNhdGlvbiIsImEiOiJIZ2VvODFjIn0.TDw5VdwGavwEsch53sAVxA'
          # set up the initial view
          $scope.setViewMode 'schools'
          if $scope.schoolType == 'primary'
            $scope.rankBy = 'performance'
          $scope.setYear 2014  # hard-coded default to speed up page-load
          $scope.visMode = if $scope.schoolType == 'primary' then 'passrate' else 'gpa' # this shall be the default visMode
          OpenDataApi.getYears $scope.schoolType, $scope.rankBy
            .then (years) -> $scope.years = _(years).map (y) -> y.YEAR_OF_RESULT
          # fix the map's container awareness (it gets it wrong)
          $timeout (-> map.invalidateSize()), 1


        processPin = (code, layer) ->
          colorPin code, layer
          layer.on 'mouseover', -> $scope.$apply ->
            $scope.hover code
          layer.on 'mouseout', -> $scope.$apply ->
            $scope.unHover()
          layer.on 'click', -> $scope.$apply ->
            $scope.select code

        processPoly = (feature, layer) ->
          colorPoly feature, layer
          layer.on 'mouseover', -> $scope.$apply ->
            $scope.hover feature.id
          layer.on 'mouseout', -> $scope.$apply ->
            $scope.unHover()
          layer.on 'click', -> $scope.$apply ->
            $scope.select feature.id


        colorPin = (code, layer) ->
          findSchool(code).then (school) ->
            val = school[$scope.visMetric]
            layer.setStyle colorSrv.pinOff $scope.getColor val

        colorPoly = (feature, layer) ->
          val = feature.properties[$scope.visMetric]
          layer.setStyle colorSrv.polygonOff $scope.getColor val

        getDetailsByPoly = (schools, polyType, schoolType) ->
          detailsByPoly = {}
          schoolsByPoly = groupBy schools, polyGroupProp polyType
          for id, regSchools of schoolsByPoly
            byOwner = groupBy regSchools, 'OWNERSHIP'
            detailsByPoly[id] =
              CHANGE_PREVIOUS_YEAR: averageProp regSchools, 'CHANGE_PREVIOUS_YEAR'  # TODO: confirm
              PASS_RATE: averageProp regSchools, 'PASS_RATE'
              GOVT_SCHOOLS: byOwner.GOVERNMENT?.length
              NON_GOVT_SCHOOLS: byOwner['NON GOVERNMENT']?.length
              UNKNOWN_SCHOOLS: regSchools.length - byOwner.GOVERNMENT?.length - byOwner['NON GOVERNMENT']?.length

            # get the region for any district via school data
            if polyType == 'districts'
              [[region, blah], extras...] = ([r, s] for r, s of groupBy schoolsByPoly[id], 'REGION')
                .map ([region, schools]) -> [region, schools.length]
                .sort ([ra, sa], [rb, sb]) -> sb - sa
              if extras? > 1
                $log.warn "District has schools with different regions: #{id}"
              detailsByPoly[id].REGION = region

            angular.extend detailsByPoly[id],
              if schoolType == 'primary'
                AVG_MARK: averageProp regSchools, 'AVG_MARK'
              else if schoolType == 'secondary'
                AVG_GPA: averageProp regSchools, 'AVG_GPA'
                CHANGE_PREVIOUS_YEAR_GPA: averageProp regSchools, 'CHANGE_PREVIOUS_YEAR_GPA'
              else
                throw new Error 'Expected "primary" or "secondary" for schoolType'
          detailsByPoly

        polyGroupProp = (polyType) ->
          switch polyType
            when 'regions' then 'REGION'
            when 'districts' then 'DISTRICT'
            else throw new Error "cannot group polygons by unknown polyType '#{polyType}'"

        groupBy = (rows, prop) ->
          grouped = {}
          for row in rows
            unless grouped[row[prop]]?
              grouped[row[prop]] = []
            grouped[row[prop]].push row
          grouped

        average = (nums) -> (nums.reduce (a, b) -> a + b) / nums.length

        averageProp = (rows, prop) -> average _(rows).map (r) -> r[prop]

        search = (query) ->
          if query?
            OpenDataApi.search $scope.schoolType, $scope.rankBy, query, $scope.year
              .then (data) -> $q.all _(data).map (s) -> findSchool s.CODE
                .then (schools) ->
                  $scope.searchText = query
                  $scope.searchChoices = _.unique schools

        # todo: figure out if these are needed
        $scope.getTimes = (n) ->
            new Array(n)

        $scope.anchorScroll = () ->
            $anchorScroll()



]
