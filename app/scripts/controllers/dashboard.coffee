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
    '_', '$q', 'WorldBankApi', 'layersSrv', 'chartSrv', '$log','$location','$translate',
    '$timeout', 'MetricsSrv', 'colorSrv', 'OpenDataApi', 'loadingSrv'

    ($scope, $window, $routeParams, $anchorScroll, $http, leafletData,
    _, $q, WorldBankApi, layersSrv, chartSrv, $log, $location, $translate,
    $timeout, MetricsSrv, colorSrv, OpenDataApi, loadingSrv) ->

        # other state
        layers = {}
        currentLayer = null
        schoolCodeMap = {}

        #### Template / Controller API via $scope ####

        # app state
        angular.extend $scope,
          year: null  # set after init
          years: null
          yearAggregates: null
          viewMode: null  # set after init
          visMode: 'passrate'
          schoolType: $routeParams.type
          hovered: null
          lastHovered: null
          selected: null
          allSchools: null
          filteredSchools: null
          pins: null
          rankBy: null  # performance or improvement for primary
          rankedBy: null
          moreThan40: null  # students, for secondary schools

        # state transitioners
        angular.extend $scope,
          setYear: (newYear) -> $scope.year = newYear
          setViewMode: (newMode) -> $scope.viewMode = newMode
          setVisMode: (newMode) -> $scope.visMode = newMode
          setSchoolType: (newType) -> $location.path "/dashboard/#{newType}/"
          hover: (code) ->  (findSchool code).then ((s) -> $scope.hovered = s), $log.error
          keepHovered: -> $scope.hovered = $scope.lastHovered
          unHover: -> $scope.hovered = null
          select: (code) -> (findSchool code).then ((s) -> $scope.selected = s), $log.error
          search: (q) -> search q

        # view util functions
        angular.extend $scope,
          Math: Math


        # State Listeners

        $scope.$watchGroup ['viewMode', 'year', 'schoolType', 'rankBy', 'moreThan40'],
          ([viewMode, year, rest...], [oldViewMode]) -> if year?
            if viewMode == 'schools' then loadSchools viewMode, year, rest...
            else if oldViewMode == 'schools' then clearSchools()

        $scope.$watchGroup ['schoolType', 'rankBy', 'moreThan40'],
          ([schoolType, rankBy, moreThan40]) ->
            OpenDataApi.getYearAggregates schoolType, rankBy, moreThan40
              .then (years) ->
                $scope.yearAggregates = _(years).reduce ((agg, y) ->
                  agg[y.YEAR_OF_RESULT] =
                    PASS_RATE: y.average_pass_rate
                  agg
                ), {}

        $scope.$watch 'allSchools', (promise) -> if promise?
          ranked = $q.defer()
          $scope.rankedBy = ranked.promise
          promise.then (schools) -> if schools?
            _(schools).each (school) -> schoolCodeMap[school.CODE] = school
            detailsPromise = OpenDataApi.getSchoolDetails $scope
              .then (schools) ->
                _(schools).each (details) -> angular.extend schoolCodeMap[details.CODE], details
                rankSchools switch $scope.rankBy
                    when 'performance' then ['RANK']
                    when 'improvement' then ['CHANGE_PREVIOUS_YEAR', true]
                    when null then ['CHANGE_PREVIOUS_YEAR', true]  # secondary
                    else throw new Error "invalid rankBy: '#{$scope.rankBy}'"
                  .then ranked.resolve
          loadingSrv.containerLoad promise, document.getElementById mapId

        $scope.$watchGroup ['allSchools'], ([allSchools]) -> if allSchools?
          $scope.filteredSchools = $q (resolve, reject) ->
            allSchools.then resolve, reject

        $scope.$watch 'filteredSchools', (schools, oldSchools) ->
          layerId = "schools-#{$scope.year}-#{$scope.schoolType}-#{$scope.moreThan40}"
          if schools?
            mapped = $q (resolve, reject) ->
              map = (data) -> if data?
                resolve data.map (s) -> [ s.LATITUDE, s.LONGITUDE, s.CODE ]
              schools.then map, reject
            schools.then (schools) ->
              $scope.pins = layersSrv.addFastCircles layerId, mapId,
                getData: () -> mapped
                options:
                  className: 'school-location'
                  radius: 8
                  onEachFeature: processPin

        $scope.$watch 'pins', (blah, oldPins) -> if oldPins?
          oldPins.then (pins) ->
            leafletData.getMap(mapId).then (map) -> map.removeLayer pins

        $scope.$watch 'schoolMarker', (blah, oldMarker) -> if oldMarker?
          oldMarker.then (marker) ->
              leafletData.getMap(mapId).then (map) -> map.removeLayer marker

        $scope.$watchGroup ['pins', 'visMode'], ([pinsP]) -> if pinsP?
          pinsP.then (pins) ->
            pins.eachVisibleLayer colorPin

        $scope.$watch 'viewMode', (newMode, oldMode) ->
          if newMode not in ['schools', 'national', 'regional']
            console.error 'changed to invalid view mode:', newMode
            return
          # unless newMode == oldMode  # doesnt work for initial render
          leafletData.getMap(mapId).then (map) ->
            unless currentLayer == null
              map.removeLayer currentLayer
              currentLayer = null

        $scope.$watch 'hovered', (thing, oldThing) ->
          if thing != null
            $scope.lastHovered = thing
            if $scope.viewMode == 'schools'
              getSchoolPin(thing.CODE).then (pin) ->
                pin.bringToFront()
                pin.setRadius 12
                colorPin thing.CODE, pin, true
            #   when 'regional' then weight: 5, opacity: 1

          if oldThing != null
            if $scope.viewMode == 'schools'
              getSchoolPin(oldThing.CODE).then (pin) ->
                pin.setRadius 8
                colorPin oldThing.CODE, pin
              # when 'regional' then weight: 0, opacity: 0.6

        $scope.$watch 'selected', (school) ->
          if school != null
            if $scope.viewMode == 'schools'
              setSchool school

        $scope.$on 'filtersToggle', (event, opts) ->
          $scope.filtersHeight = opts.height

        loadSchools = (viewMode, year, schoolType, rankBy, moreThan40) ->
          $scope.allSchools = OpenDataApi.getSchools
              year: year
              schoolType: schoolType
              subtype: rankBy
              moreThan40: moreThan40
            .catch (err) -> $log.error err
          # leaving this as is for now, since we don't have this at school level
          MetricsSrv.getPupilTeacherRatio({level: schoolType}).then (data) ->
            $scope.pupilTeacherRatio = data.rate

        clearSchools = ->
          $scope.allSchools = null
          $scope.filteredSchools = null
          $scope.pins = null
          $scope.rankedBy = null
          $scope.schoolMarker = null

        setSchool = (school) ->
          latlng = [school.LATITUDE, school.LONGITUDE]
          markSchool latlng
          leafletData.getMap(mapId).then (map) ->
            map.setView latlng, (Math.max 9, map.getZoom())
          rankField = switch $scope.rankBy
            when 'performance' then 'RANK'
            when 'improvement' then 'CHANGE_PREVIOUS_YEAR'
            when null then 'CHANGE_PREVIOUS_YEAR'  # secondary TODO fix me
            else throw new Error "invalid rankBy: '#{$scope.rankBy}'"
          if school[rankField]?
            rankSchools [rankField, false, true]
              .then (ranked) ->
                nationalRank = ranked.indexOf school
                chartSrv.drawNationalRanking nationalRank+1, ranked.length
          unless school.ranks?
            $q.all
                region: (rank school, 'REGION')
                district: (rank school, 'DISTRICT')
              .then (ranks) ->
                school.ranks = ranks

          unless school.yearAggregates?
            OpenDataApi.getSchoolAggregates $scope.schoolType, $scope.rankBy, school.CODE
              .then (data) ->
                school.yearAggregates = _(data).reduce ((agg, year) ->
                  agg[year.YEAR_OF_RESULT] =
                    PASS_RATE: year.PASS_RATE
                  agg
                ), {}

        findSchool = (code) ->
          $q (resolve, reject) ->
            if $scope.allSchools?
              findIt = (schools) ->
                if schoolCodeMap[code]?
                  resolve schoolCodeMap[code]
                else
                  reject "Could not find school by code '#{code}'"
              $scope.allSchools.then findIt, reject
            else
              reject 'No schools to find from'

        getSchoolPin = (code) ->
          $q (resolve, reject) ->
            $scope.pins.then ((pins) -> resolve pins.getLayer code), reject

        # get the (rank, total) of a school, filtered by its region or district
        rank = (school, rank_by) ->
          if rank_by not in ['REGION', 'DISTRICT']
            throw new Error "invalid rank_by: '#{rank_by}'"
          $q (resolve, reject) ->
            rankSchool = (schools) ->
              if school[rank_by] == undefined
                return resolve [undefined, undefined]
              ranked = schools
                .filter (s) -> s[rank_by] == school[rank_by]
                .sort (a, b) -> a.rank - b.rank # TODO fix me, this should be base on the type of dashboard
              resolve
                rank: (ranked.indexOf school) + 1
                total: ranked.length

            $scope.allSchools.then rankSchool, reject

        rankSchools = ([rank_by, desc, all]) ->
          rb = rank_by
          if rb not in ['CHANGE_PREVIOUS_YEAR', 'RANK']
            throw new Error "invalid rank_by: '#{rb}'"
          $q (resolve, reject) ->
            getRanked = (schools) ->
              list = _.unique(schools
                .filter (s) -> s[rb]?
                .sort (a, b) -> if desc then b[rb] - a[rb] else a[rb] - b[rb]
              )
              resolve if all then list else list.slice 0, 20
            $scope.allSchools.then getRanked, reject


        # widget local state (maybe should move to other directives)
        $scope.searchText = "dar"
        $scope.schoolsChoices = []

        # controller constants
        mapId = 'map'

        # other global-ish stuff
        schoolMarker = null

        if $routeParams.type isnt 'primary' and $routeParams.type isnt 'secondary'
          $timeout -> $location.path '/'

        # INIT
        leafletData.getMap(mapId).then (map) ->
          # initialize the map view
          map.setView [-7.199, 34.1894], 6
          # add the basemap
          layersSrv.addTileLayer 'gray', mapId, '//{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
          # set up the initial view
          $scope.setViewMode 'schools'
          if $scope.schoolType == 'primary'
            $scope.rankBy = 'performance'
          $scope.setYear 2014  # hard-coded default to speed up page-load
          OpenDataApi.getYears $scope.schoolType, $scope.rankBy
            .then (years) -> $scope.years = _(years).map (y) -> y.YEAR_OF_RESULT


        processPin = (code, layer) ->
          colorPin code, layer
          layer.on 'mouseover', -> $scope.$apply ->
            $scope.hover code
          layer.on 'mouseout', -> $scope.$apply ->
            $scope.unHover()
          layer.on 'click', -> $scope.$apply ->
            $scope.select code

        mapLayerCreators =
          regional: ->
            getData = -> $q (resolve, reject) ->
              WorldBankApi.getDistricts $scope.schoolType
                .success (data) ->
                  resolve
                    type: 'FeatureCollection'
                    features: data.rows.map (district) ->
                      type: 'Feature'
                      geometry: JSON.parse district.geojson
                      properties: angular.extend district, geojson: null
                .error reject
            options =
              onEachFeature: (feature, layer) -> attachLayerEvents layer
            layersSrv.addGeojsonLayer "regions-#{$scope.schoolType}", mapId,
              getData: getData
              options: options


        colorPin = (code, l, hovered) -> findSchool(code).then (school) ->
          v = switch
            when $scope.visMode == 'passrate' then school.PASS_RATE
            when $scope.visMode == 'ptratio' then school.pt_ratio
          l.setStyle colorSrv.pinStyle v, $scope.visMode, hovered

        groupByDistrict = (rows) ->
          districts = {}
          for row in rows
            unless districts[row.district]
              districts[row.district] = {pt_ratio: [], pass_2014: []}
            for prop in ['pt_ratio', 'pass_2014']
              districts[row.district][prop].push(row[prop])
          districts

        average = (nums) -> (nums.reduce (a, b) -> a + b) / nums.length

        colorRegions = ->
          if $scope.viewMode != 'regional'
            console.error 'colorRegions should only be called when viewMode is "regional"'
            return
          WorldBankApi.getSchools($scope.schoolType).success (data) ->
            byRegion = groupByDistrict data.rows
            _(currentLayer.getLayers()).each (l) ->
              regionData = byRegion[l.feature.properties.NAME]
              if not regionData
                v = null
              else if $scope.visMode == 'passrate'
                v = average(regionData.pass_2014)
              else
                v = average(regionData.pt_ratio)
              l.setStyle colorSrv.areaStyle v, $scope.visMode

        markSchool = (latlng) ->
          unless $scope.schoolMarker?
            icon = layersSrv.awesomeIcon markerColor: 'blue', icon: 'map-marker'
            $scope.schoolMarker = layersSrv.marker 'school-marker', mapId,
              latlng: latlng
              options: icon: icon

          $scope.schoolMarker.then (marker) ->
            marker.setLatLng latlng

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
