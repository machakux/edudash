'use strict'

###*
 # @ngdoc service
 # @name edudashApp.OpenDataApi
 # @description
 # # OpenDataApi
 # Service in the edudashApp.
###
angular.module 'edudashApp'
.service 'OpenDataApi', [
    '$http', '$resource', '$log', 'CsvParser'
    ($http, $resource, $log, CsvParser) ->
      # AngularJS will instantiate a singleton by calling "new" on this function
      corsApi = 'https://cors-anywhere.herokuapp.com'
      apiRoot = '/opendata.go.tz/api/action/'
      oapiRoot = 'http://wbank.cartodb.com/api/v2/sql'
      oapiKey = 'ad10ae57cef93e98482aabcf021a738a028c168b'

      getdata: () ->
        $params =
          resource_id: '3221ccb4-3b75-4137-a8bd-471a436ed7a5'
        req = $resource(corsApi + apiRoot + 'datastore_search')
        req.get($params).$promise

      getDataset: (id) ->
        $params =
          resource_id: id
        req = $resource(corsApi + apiRoot + 'datastore_search')
        req.get($params).$promise

      getDatasetType: (level) ->
        $params =
          id: level
        req = $resource(corsApi + apiRoot + 'package_show')
        req.get($params).$promise

      getodata: () ->
        $params =
          q: 'SELECT * FROM wbank.tz_primary_cleaned_dashboard ORDER BY rank_2014 ASC LIMIT 100'
          api_key: oapiKey
        $http.get(oapiRoot, {params: $params})

      getCsv: (file) ->
        file = file.replace(/^(http|https):\/\//gm, '')
        resourceUrl = corsApi + '/' + file
        $resource(resourceUrl, {},
          getDataSet: {
            method: 'GET'
            isArray: false
            headers:
              'Content-Type': 'text/csv; charset=utf-8'
            responseType: 'text'
            transformResponse: (data, headers) ->
              #$log.debug 'csv raw data'
              result = CsvParser.parseToJson data
              #$log.debug result
              result
          }
        )

#        .success (data, status) ->
#          $log.debug 'csv raw data' + status
#          $log.debug CsvParser.parseToJson data
#        req = $resource(resourceUrl)
#        req.get().$promise

      getMyData: () ->
        [
          '1- HTML5 Boilerplate'
          '2- AngularJS'
          '3- Karma'
        ]
  ]
