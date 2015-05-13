'use strict'

###*
 # @ngdoc service
 # @name edudashApp.CsvParser
 # @description
 # # CsvParser
 # Service in the edudashApp.
###
angular.module 'edudashApp'
.service 'CsvParser', [
    '$log'
    ($log) ->
      # TODO transform it to coffeescript way
      parseToJson: (csv) ->
        lines = csv.split('\n')
        result = []
        headers = lines[0].replace(/^\s+|\s+|\\r$/gm, '').split(',')
        i = 1
        while i < lines.length
          obj = {}
          if(lines[i].length > 0)
            currentline = lines[i].replace(/^\s+|\s+|\\r$/gm, '').split(',')
            j = 0
            while j < headers.length
              obj[headers[j]] = currentline[j]
              j++
            result.push obj
          i++
        #return result; //JavaScript object
        result:
          fields: headers
          records: result
      ]
