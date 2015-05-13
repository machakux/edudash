'use strict'

describe 'Filter: sumUpFilter', ->

  # load the filter's module
  beforeEach module 'edudashApp'

  # initialize a new instance of the filter before each test
  sumUpFilter = {}
  beforeEach inject ($filter) ->
    sumUpFilter = $filter 'sumUpFilter'

#  it 'should return the input prefixed with "sumUpFilter filter:"', ->
#    text = 'angularjs'
#    expect(sumUpFilter text).toBe ('sumUpFilter filter: ' + text)
