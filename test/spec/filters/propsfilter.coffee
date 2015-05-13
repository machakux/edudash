'use strict'

describe 'Filter: propsFilter', ->

  # load the filter's module
  beforeEach module 'edudashApp'

  # initialize a new instance of the filter before each test
  propsFilter = {}
  beforeEach inject ($filter) ->
    propsFilter = $filter 'propsFilter'

#  it 'should return the input prefixed with "propsFilter filter:"', ->
#    text = 'angularjs'
#    expect(propsFilter text).toBe ('propsFilter filter: ' + text)
