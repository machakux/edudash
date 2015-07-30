'use strict'

###*
 # @ngdoc service
 # @name edudashApp.WorldBankApi
 # @description
 # # WorldBankApi
 # Service in the edudashApp.
###
angular.module 'edudashAppSrv'
  .service 'colorSrv', ->

    colors:
      unknown: '#aaa'
      poor: '#f56053'
      medium: '#e9c941'
      good: '#38a21c'

    categorize: (val, mode) ->
      switch
        when mode == 'passrate' then switch
          when val == null then 'unknown'
          when val < 40 then 'poor'
          when val < 60 then 'medium'
          else 'good'
        when mode == 'ptratio' then switch
          when val == null then 'unknown'
          when val < 35 then 'good'
          when val > 50 then 'poor'
          else 'medium'

    colorize: (val, mode) ->
      this.colors[this.categorize val, mode]

    pinStyle: (val, mode, hovered) ->
      weight: if hovered then 6 else 2
      opacity: 1
      color: if hovered then '#05a2dc' else '#fff'
      fillOpacity: 1
      fillColor: this.colorize val, mode

    areaStyle: (val, mode) ->
      weight: 2
      color: '#fff'
      fillColor: this.colorize val, mode
      fillOpacity: 0.75
