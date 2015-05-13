'use strict'

describe 'Service: cartodb', ->

  # load the service's module
  beforeEach module 'edudashApp'

  # instantiate service
  cartodb = {}
  beforeEach inject (_cartodb_) ->
    cartodb = _cartodb_

#  it 'should do something', ->
#    expect(!!cartodb).toBe true
