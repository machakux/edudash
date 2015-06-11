'use strict'

###*
 # @ngdoc function
 # @name edudashApp.controller:DashboardsCtrl
 # @description
 # # DashboardsCtrl
 # Controller of the edudashApp
###
angular.module('edudashAppCtrl').controller 'DashboardCtrl', [
    '$scope', '$window', '$routeParams', '$anchorScroll', '$http', 'leafletData', '_', '$q', 'WorldBankApi', 'layersSrv', 'chartSrv', '$log','$location','$translate',
    '$timeout', 'MetricsSrv'


    ($scope, $window, $routeParams, $anchorScroll, $http, leafletData, _, $q, WorldBankApi, layersSrv, chartSrv, $log, $location, $translate, $timeout, MetricsSrv) ->
        primary = 'primary'
        secondary = 'secondary'
        title =
          primary: 'Primary School Dashboard'
          secondary: 'Secondary School Dashboard'

        $scope.schoolType = $routeParams.type
        $scope.title = title[$routeParams.type]

        if $routeParams.type isnt primary and $routeParams.type isnt secondary
          $timeout -> $location.path '/'


        $scope.searchText = "dar"

        layers = {}
        currentLayer = null

        $scope.mapView = 'schools'
        $scope.activeItem = null
        $scope.schoolsChoices = []
        $scope.hoveredSchool = null
        schoolMarker = null
        $scope.openMapFilter = false
        $scope.openSchoolLegend = false
        ptMin = 0
        ptMax = 150
        $scope.passRange =
            min: 0
            max: 100
        $scope.ptRange =
            min: ptMin
            max: ptMax
        $scope.filterPassRate = {
          range: {
              min: 0,
              max: 100
          },
          minValue: 0,
          maxValue: 100
        };
        $scope.filterPupilRatio = {
          range: {
              min: 0,
              max: 10
          },
          minValue: 0,
          maxValue: 10
        };

        visModes = ['passrate', 'ptratio']
        $scope.visMode = 'passrate'

        mapId = 'map'


        leafletData.getMap(mapId).then (map) ->
          # initialize the map view
          map.setView [-7.199, 34.1894], 6

          # add the basemap
          layersSrv.addTileLayer 'gray', '//{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png', mapId

          # add the current layer
          if $scope.mapView == 'schools'
            dataPromise = $q (resolve, reject) ->
              WorldBankApi.getSchools $scope.schoolType
                .success (data) ->
                  resolve
                    type: 'FeatureCollection'
                    features:
                      data.rows.map (school) ->
                        type: 'Feature'
                        id: school.cartodb_id
                        geometry:
                          type: 'Point'
                          coordinates: [school.longitude, school.latitude]
                        properties: school
                .error reject

            options =
              pointToLayer: (geojson, latlng) ->
                L.circleMarker latlng,
                  className: 'school-location'
                  radius: 8
                  color: '#fff'
                  fillColor: '#777'
              onEachFeature: (feature, layer) ->
                layer.on 'mouseover', -> $scope.$apply ->
                  $scope.hoveredSchool = feature.properties
                layer.on 'mouseout', -> $scope.$apply ->
                  $scope.hoveredSchool = null
                layer.on 'click', -> $scope.$apply ->
                  $scope.setSchool feature.properties

            layers['schools'] = layersSrv.addGeojsonLayer 'schools', dataPromise, options, mapId

          # set up the initial view
          $scope.showView 'schools'

        colourize = ->
          if $scope.mapView == 'schools'
            _(currentLayer.raw.getLayers()).each (l) ->
              if $scope.visMode == 'passrate'
                passrate = l.feature.properties.pass_2014
                if passrate == null
                  l.setStyle
                    color: '#aaa'  # stroke
                    fillOpacity: 0
                else
                  l.setStyle
                    color: '#fff'  # stroke
                    fillColor: if passrate < 40 then '#f56053' else
                      if passrate < 60 then '#e9c941' else '#38a21c'
                    fillOpacity: 0.75
              else if $scope.visMode == 'ptratio'
                ptratio = l.feature.properties.pt_ratio
                if ptratio == null
                  l.setStyle
                    color: '#aaa'  # stroke
                    fillOpacity: 0
                else
                  l.setStyle
                    color: '#fff'  # stroke
                    fillColor: if ptratio < 35 then '#38a21c' else
                      if ptratio > 50 then '#f56053' else '#e9c941'
                    fillOpacity: 0.75


        WorldBankApi.getBestSchool($scope.schoolType).success (data) ->
            $scope.bestSchools = data.rows

        WorldBankApi.getWorstSchool($scope.schoolType).success (data) ->
            $scope.worstSchools = data.rows

        WorldBankApi.mostImprovedSchools($scope.schoolType).success (data) ->
            $scope.mostImprovedSchools = data.rows

        WorldBankApi.leastImprovedSchools($scope.schoolType).success (data) ->
            $scope.leastImprovedSchools = data.rows

        $scope.setSchoolType = (to) ->
          $location.path "/dashboard/#{to}/"

        $scope.setVisMode = (to) ->
          unless (visModes.indexOf to) == -1
            $scope.visMode = to
            colourize()
          else
            console.error 'Could not change visualization to invalid mode:', to

        $scope.showView = (view) ->
          layers[view].then (layer) ->
            layer.show()
            currentLayer = layer
            colourize()

        $scope.toggleMapFilter = () ->
            $scope.openMapFilter = !$scope.openMapFilter

        $scope.toggleSchoolLegend = () ->
            $scope.openSchoolLegend = !$scope.openSchoolLegend

        updateMap = () ->
          if $scope.mapView != 'district'
            # Include schools with no pt_ratio are also shown when the pt limits in extremeties
            if $scope.ptRange.min == ptMin and $scope.ptRange.max == ptMax
                WorldBankApi.updateLayers(layers, $scope.schoolType, $scope.passRange)
            else
                WorldBankApi.updateLayersPt(layers, $scope.schoolType, $scope.passRange, $scope.ptRange)

        $scope.updateMap = _.debounce(updateMap, 500)

        $scope.getSchoolsChoices = (query) ->
            if query?
              WorldBankApi.getSchoolsChoices($scope.schoolType, query).success (data) ->
                $scope.searchText = query
                $scope.schoolsChoices = data.rows

        $scope.$watch 'passRange', ((newVal, oldVal) ->
            unless _.isEqual(newVal, oldVal)
                $scope.updateMap()
            return
        ), true

        $scope.$watch 'ptRange', ((newVal, oldVal) ->
            unless _.isEqual(newVal, oldVal)
                $scope.updateMap()
            return
        ), true

        markSchool = (latlng) ->
          unless schoolMarker?
            icon = layersSrv.awesomeIcon markerColor: 'blue', icon: 'map-marker'
            schoolMarker = layersSrv.marker 'school-marker', latlng, {icon: icon}, mapId

          schoolMarker.then (marker) ->
            marker.raw.setLatLng latlng
            marker.show()

        $scope.setMapView = (latlng, zoom, view) ->
            if view?
                $scope.mapView = view
                $scope.showView(view)
            unless zoom?
                zoom = 9
            leafletData.getMap(mapId).then (map) ->
                map.setView latlng, zoom

        $scope.setSchool = (item, model, showAllSchools) ->
            unless $scope.selectedSchool? and item.cartodb_id == $scope.selectedSchool.cartodb_id
              filter =
                year: '2012'
                selectedSchool: item
                field: 'district'
                educationLevel: $scope.schoolType
              WorldBankApi.getRank(filter).then (result) ->
                $scope.districtRank = result.data.rows[0]
              filter.field = 'region'
              WorldBankApi.getRank(filter).then (result) ->
                $scope.regionRank = result.data.rows[0]

            $scope.selectedSchool = item
            unless showAllSchools? and showAllSchools == false
                $scope.mapView = 'schools'
                $scope.showView('schools')
            # Silence invalid/null coordinates
            leafletData.getMap(mapId).then (map) ->
              try
                  if map.getZoom() < 9
                     zoom = 9
                  else
                      zoom = map.getZoom()
                  latlng = [$scope.selectedSchool.latitude, $scope.selectedSchool.longitude];
                  markSchool latlng
                  map.setView latlng, zoom
              catch e
                  console.log e
            if item.pass_2014 < 10 && item.pass_2014 > 0
                $scope.selectedSchool.pass_by_10 = 1
            else
                $scope.selectedSchool.pass_by_10 = Math.round item.pass_2014/10
            $scope.selectedSchool.fail_by_10 = 10 - $scope.selectedSchool.pass_by_10

            # TODO: cleaner way?
            # Ensure the parent div has been fully rendered
            setTimeout( () ->
              if $scope.mapView == 'schools'
                console.log chartSrv
                chartSrv.drawNationalRanking item, $scope.schoolType, $scope.worstSchools[0].rank_2014
                $scope.passratetime = chartSrv.drawPassOverTime item

            , 400)

        $scope.getTimes = (n) ->
            new Array(n)

        $scope.anchorScroll = () ->
            $anchorScroll()

        WorldBankApi.getPassOverTime({educationLevel: $scope.schoolType}).then (result) ->
          parseList = chartSrv.drawPassOverTime result.data.rows[0]
          parseList = parseList.map (x) -> {key: x.key, val: parseInt(x.val)}
          $scope.globalpassratetime = parseList
        WorldBankApi.getTopDistricts({educationLevel: $scope.schoolType, metric: 'avg_pass_rate', order: 'DESC'}).then (result) ->
          $scope.bpdistrics = result.data.rows
        WorldBankApi.getTopDistricts({educationLevel: $scope.schoolType, metric: 'avg_pass_rate', order: 'ASC'}).then (result) ->
          $scope.wpdistrics = result.data.rows
        WorldBankApi.getTopDistricts({educationLevel: $scope.schoolType, metric: 'change', order: 'DESC'}).then (result) ->
          $scope.midistrics = result.data.rows
        WorldBankApi.getTopDistricts({educationLevel: $scope.schoolType, metric: 'change', order: 'ASC'}).then (result) ->
          $scope.lidistrics = result.data.rows
        MetricsSrv.getPupilTeacherRatio({level: $scope.schoolType}).then (data) ->
          $scope.pupilTeacherRatio = data.rate
        WorldBankApi.getGlobalPassrate($scope.schoolType).success (data) ->
          $scope.passrate = data.rows[0].avg
        WorldBankApi.getGlobalChange($scope.schoolType).success (data) ->
          $scope.passRateChange = parseInt data.rows[0].avg

]
