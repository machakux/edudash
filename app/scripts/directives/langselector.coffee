'use strict'

###*
 # @ngdoc directive
 # @name edudashApp.directive:langSelector
 # @description
 # # langSelector
###
angular.module('i18nEdudashApp', [
  'ngCookies',
  'ngMessages',
  'ngResource',
  'pascalprecht.translate'])

  .directive('langSelector', [
    "$log", "$translate"
    ($log, $translate) ->
      restrict: 'E'
      templateUrl: 'views/langselector.html'
      link: (scope, element, attrs) ->
        scope.langList = [
          {
            lang: 'en'
            label: 'English'
          }
          {
            lang: 'sw-tz'
            label: 'Kiswahili'
          }
        ]
        scope.selectedLang = 'en'
        scope.changeLanguage = (key) ->
          $translate.use(key)
          scope.selectedLang = key
  ])
  .config ($translateProvider) ->
    $translateProvider.useStaticFilesLoader(
      prefix: 'i18n/locale_'
      suffix: '.json'
    )
    $translateProvider.preferredLanguage('en');
    $translateProvider.useSanitizeValueStrategy('escaped');

