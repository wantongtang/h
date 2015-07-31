{module, inject} = angular.mock

describe 'AppController', ->
  $controller = null
  $scope = null
  fakeAnnotationMapper = null
  fakeAnnotationUI = null
  fakeAuth = null
  fakeDrafts = null
  fakeFeatures = null
  fakeIdentity = null
  fakeLocation = null
  fakeParams = null
  fakeSession = null
  fakeStore = null
  fakeStreamer = null
  fakeStreamFilter = null
  fakeThreading = null

  sandbox = null

  createController = ->
    $controller('AppController', {$scope: $scope})

  before ->
    angular.module('h', ['ngRoute'])
    .controller('AppController', require('../app-controller'))
    .controller('AnnotationUIController', angular.noop)

  beforeEach module('h')

  beforeEach module ($provide) ->
    sandbox = sinon.sandbox.create()

    fakeAnnotationMapper = {
      loadAnnotations: sandbox.spy()
    }

    fakeAnnotationUI = {
      tool: 'comment'
      clearSelectedAnnotations: sandbox.spy()
    }

    fakeAuth = {
      user: undefined
    }

    fakeDrafts = {
      contains: sandbox.stub()
      remove: sandbox.spy()
      all: sandbox.stub().returns([])
      discard: sandbox.spy()
    }

    fakeFeatures = {
      fetch: sandbox.spy()
      flagEnabled: sandbox.stub().returns(false)
    }

    fakeIdentity = {
      watch: sandbox.spy()
      request: sandbox.spy()
    }

    fakeLocation = {
      search: sandbox.stub().returns({})
    }

    fakeParams = {id: 'test'}

    fakeSession = {}

    fakeStore = {
      SearchResource: {
        get: sinon.spy()
      }
    }

    fakeStreamer = {
      open: sandbox.spy()
      close: sandbox.spy()
      send: sandbox.spy()
    }

    fakeStreamFilter = {
      setMatchPolicyIncludeAny: sandbox.stub().returnsThis()
      addClause: sandbox.stub().returnsThis()
      getFilter: sandbox.stub().returns({})
    }

    fakeThreading = {
      idTable: {}
      register: (annotation) ->
        @idTable[annotation.id] = message: annotation
    }

    $provide.value 'annotationMapper', fakeAnnotationMapper
    $provide.value 'annotationUI', fakeAnnotationUI
    $provide.value 'auth', fakeAuth
    $provide.value 'drafts', fakeDrafts
    $provide.value 'features', fakeFeatures
    $provide.value 'identity', fakeIdentity
    $provide.value '$location', fakeLocation
    $provide.value '$routeParams', fakeParams
    $provide.value 'session', fakeSession
    $provide.value 'store', fakeStore
    $provide.value 'streamer', fakeStreamer
    $provide.value 'streamfilter', fakeStreamFilter
    $provide.value 'threading', fakeThreading
    return

  beforeEach inject (_$controller_, $rootScope) ->
    $controller = _$controller_
    $scope = $rootScope.$new()

  afterEach ->
    sandbox.restore()

  it 'does not show login form for logged in users', ->
    createController()
    assert.isFalse($scope.accountDialog.visible)

  it 'does not show the share dialog at start', ->
    createController()
    assert.isFalse($scope.shareDialog.visible)

  describe 'applyUpdate', ->

    it 'calls annotationMapper.loadAnnotations() upon "create" action', ->
      createController()
      anns = ["my", "annotations"]
      fakeStreamer.onmessage
        type: "annotation-notification"
        options: action: "create"
        payload: anns
      assert.calledWith fakeAnnotationMapper.loadAnnotations, anns

    it 'calls annotationMapper.loadAnnotations() upon "update" action', ->
      createController()
      anns = ["my", "annotations"]
      fakeStreamer.onmessage
        type: "annotation-notification"
        options: action: "update"
        payload: anns
      assert.calledWith fakeAnnotationMapper.loadAnnotations, anns

    it 'calls annotationMapper.loadAnnotations() upon "past" action', ->
      createController()
      anns = ["my", "annotations"]
      fakeStreamer.onmessage
        type: "annotation-notification"
        options: action: "past"
        payload: anns
      assert.calledWith fakeAnnotationMapper.loadAnnotations, anns

    it 'looks up annotations at threading upon "delete" action', ->
      createController()
      $scope.$emit = sinon.spy()

      # Prepare the annotation that we have locally
      localAnnotation =
        id: "fake ID"
        data: "local data"

      # Introduce our annotation into threading
      fakeThreading.register localAnnotation

      # Prepare the annotation that will come "from the wire"
      remoteAnnotation =
        id: localAnnotation.id  # same id as locally
        data: "remote data"     # different data

      # Simulate a delete action
      fakeStreamer.onmessage
        type: "annotation-notification"
        options: action: "delete"
        payload: [ remoteAnnotation ]

      assert.calledWith $scope.$emit, "annotationDeleted", localAnnotation

  it 'deletes annotations, but not drafts, on user change', ->
    createController()
    $scope.$emit = sinon.spy()

    annotation1 = id: 'abaca'
    annotation2 = id: 'deadbeef'

    fakeThreading.register(annotation1)
    fakeThreading.register(annotation2)

    fakeDrafts.contains.withArgs(annotation1).returns(true)
    fakeDrafts.contains.withArgs(annotation2).returns(false)

    fakeAuth.user = null
    $scope.$digest()

    fakeAuth.user = 'acct:loki@example.com'
    $scope.$digest()

    assert.neverCalledWith($scope.$emit, 'annotationDeleted', annotation1)
    assert.calledWith($scope.$emit, 'annotationDeleted', annotation2)
