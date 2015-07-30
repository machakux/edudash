'use strict'

###*
 # @ngdoc service
 # @name edudashApp.OpenDataApi
 # @description
 # # OpenDataApi
 # Service in the edudashApp.
###
angular.module 'edudashAppSrv'
.service 'OpenDataApi', [
    '$http', '$resource', '$log', 'CsvParser', '$location', '$q'
    ($http, $resource, $log, CsvParser, $location, $q) ->
      ckanQueryURL = '//data.takwimu.org/api/action/datastore_search_sql'
      datasetMapping =
        primary:
          'performance': '3a77adf7-925a-4a62-8c70-5e43f022b874'
          'improvement': 'bba2cbbb-97fb-48b1-aa51-8db69279fbc5'
        secondary: '743e5062-54ae-4c96-a826-16151b6f636b'

      converters =
        text: (t) -> t
        numeric: (n) -> +n

      ckanResp = (httpPromise) ->
        $q (resolve, reject) ->
          parse = (resp) ->
            if resp.data.success
              convertMap = resp.data.result.fields.reduce ((m, c) ->
                unless converters[c.type]?
                  reject "Unknown data type: '#{c.type}'"
                m[c.id] = converters[c.type] or converters.text
                m
              ), {}
              resolve resp.data.result.records.map (raw) ->
                conv = {}
                for key, val of raw
                  conv[key] = convertMap[key] val
                conv
            else
              reject data
          httpPromise.then parse, reject

      getTable = (educationLevel, subtype) ->
        if(subtype?)
          datasetMapping[educationLevel][subtype]
        else
          datasetMapping[educationLevel]

      getSql = (educationLevel, subtype, condition, sorted, limit, fields) ->
        strField = if fields? and fields.length > 0 then '"' + fields.join('","') + '"' else "*"
        table = getTable(educationLevel, subtype)
        sorted = if sorted? then "ORDER BY #{sorted}" else ''
        strLimit = if limit? then "LIMIT #{limit}" else ""
        "SELECT #{strField} FROM \"#{table}\" #{condition} #{sorted} #{strLimit}";

      getConditions = (educationLevel, moreThan40, year) ->
        condition = []
        if educationLevel == 'secondary' and moreThan40?
          condition.push "\"MORE_THAN_40\" = '#{if moreThan40 then 'YES' else 'NO'}'"
        if year
          condition.push '"YEAR_OF_RESULT" = ' + year
        if condition.length > 0 then "WHERE #{condition.join ' AND '}" else ""

      datasetByQuery: (query) ->
        $params =
          sql: query
        req = $resource ckanQueryURL
        req.get($params).$promise

      getLocations: ({year, schoolType, moreThan40, subtype}) ->
        ckanResp $http.get ckanQueryURL, params: sql: "
          SELECT
            \"CODE\",
            \"LATITUDE\",
            \"LONGITUDE\",
            \"NAME\"
          FROM \"#{getTable schoolType, subtype}\"
          #{getConditions schoolType, moreThan40, year}"

      getDetails: ({year, schoolType, moreThan40, subtype}) ->
        ckanResp $http.get ckanQueryURL, params: sql: "
          SELECT
            \"CODE\",
            \"DISTRICT\",
            \"PASS_RATE\",
            \"REGION\",
            \"WARD\"
          FROM \"#{getTable schoolType, subtype}\"
          #{getConditions schoolType, moreThan40, year}"

      getSchoolDetails: ({year, schoolType, rankBy, moreThan40}) ->
        extraCondition = switch schoolType
          when 'secondary' then "AND \"MORE_THAN_40\" = '#{if moreThan40 then 'YES' else 'NO'}'"
          else ''
        ckanResp $http.get ckanQueryURL, params: sql: "
          SELECT
            \"CODE\",
            \"CHANGE_PREVIOUS_YEAR\",
            \"OWNERSHIP\",
            \"RANK\"
          FROM \"#{getTable schoolType, rankBy}\"
          WHERE \"YEAR_OF_RESULT\" = #{year}
            #{extraCondition}"

      getYearAggregates: (educationLevel, subtype, moreThan40, year) ->
        condition = switch educationLevel
          when 'secondary' then "WHERE \"MORE_THAN_40\" = '#{if moreThan40 then 'YES' else 'NO'}'"
          else ''
        ckanResp $http.get ckanQueryURL, params: sql: "
          SELECT
            AVG(\"PASS_RATE\") as average_pass_rate,
            \"YEAR_OF_RESULT\"
          FROM \"#{getTable(educationLevel, subtype)}\"
          #{condition}
          GROUP BY \"YEAR_OF_RESULT\"
          ORDER BY \"YEAR_OF_RESULT\""

      search: (educationLevel, subtype, query, year) ->
        ckanResp $http.get ckanQueryURL, params: sql: "
          SELECT \"CODE\"
          FROM \"#{getTable(educationLevel, subtype)}\"
          WHERE
              (\"NAME\" ILIKE '%#{query}%'
                OR \"CODE\" ILIKE '%#{query}%')
            AND \"YEAR_OF_RESULT\" = #{year}
          LIMIT 10"

      getYears: (educationLevel, subtype) ->
        ckanResp $http.get ckanQueryURL, params: sql: "
          SELECT DISTINCT \"YEAR_OF_RESULT\"
          FROM \"#{getTable(educationLevel, subtype)}\"
          ORDER BY \"YEAR_OF_RESULT\""

      getSchoolAggregates: (educationLevel, subtype, code) ->
        ckanResp $http.get ckanQueryURL, params: sql: "
          SELECT
            \"PASS_RATE\",
            \"YEAR_OF_RESULT\"
          FROM \"#{getTable(educationLevel, subtype)}\"
          WHERE \"CODE\" = '#{code}'
          ORDER BY \"YEAR_OF_RESULT\" ASC"
  ]
