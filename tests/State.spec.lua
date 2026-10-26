local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function()
    local Iris = require(ReplicatedStorage.Iris)

    local state

    beforeEach(function()
        state = Iris.State()
    end)

    describe("State", function()
        it("Should be a state", function()
            expect(state).to.be.a("table")
            expect(state.ID).to.be.a("string")
        end)
        it("SHOULD contain nil", function()
            expect(state:get()).to.equal(nil)
            expect(state.value).to.equal(nil)
            expect(#state.ConnectedFunctions).to.equal(0)
        end)
        it("SHOULD update the value", function()
            expect(state:set(0)).to.be.ok()
            expect(state:get()).to.equal(0)
            expect(state.value).to.equal(0)
        end)
        it("SHOULD update the latest value", function()
            expect(state:set(0)).to.be.ok()
            expect(state:set(state:get() + 1)).to.be.ok()
            expect(state:get()).to.equal(1)
            expect(state.value).to.equal(1)
        end)
        it("SHOULD add a connected function", function()
            expect(state:onChange(function(value)
                expect(value).to.equal(0)
            end))
            expect(state.ConnectedFunctions).to.be.a("table")
            expect(#state.ConnectedFunctions).to.equal(1)
            expect(state.ConnectedFunctions[1]).to.never.equal(nil)
            expect(state.ConnectedFunctions[1]).to.be.a("function")
            expect(state:set(0)).to.be.ok()
        end)
        it("SHOULD chain together two states", function()
            local otherState = Iris.State()
            state:onChange(function(value)
                otherState:set(2 * value)
            end)
            state:set(10)
            expect(otherState:get()).to.equal(20)
        end)
        it("SHOULD disconnect a function", function()
            local number: number = 0
            local disconnect: () -> () = state:onChange(function(value: number)
                number = value
            end)
            expect(disconnect).to.be.a("function")
            expect(#state.ConnectedFunctions).to.equal(1)
            expect(number).to.be.equal(0)
            state:set(1)
            expect(number).to.be.equal(1)
            expect(disconnect()).to.equal(nil)
            expect(#state.ConnectedFunctions).to.equal(0)
            state:set(2)
            expect(number).to.equal(1)
        end)
        it("SHOULD keep other functions connected after a disconnect", function()
            local first, second = 0, 0
            local disconnectFirst = state:onChange(function(value: number)
                first = value
            end)
            state:onChange(function(value: number)
                second = value
            end)
            disconnectFirst()
            -- a repeated disconnect must not remove the other function.
            disconnectFirst()
            expect(#state.ConnectedFunctions).to.equal(1)

            -- connecting after a disconnect must not overwrite an existing function.
            local third = 0
            state:onChange(function(value: number)
                third = value
            end)
            expect(#state.ConnectedFunctions).to.equal(2)

            state:set(5)
            expect(first).to.equal(0)
            expect(second).to.equal(5)
            expect(third).to.equal(5)
        end)
        it("SHOULD allow a function to disconnect itself", function()
            local calls = 0
            local other = 0
            local disconnect
            disconnect = state:onChange(function()
                calls += 1
                disconnect()
            end)
            state:onChange(function(value: number)
                other = value
            end)
            state:set(1)
            state:set(2)
            expect(calls).to.equal(1)
            expect(other).to.equal(2)
        end)
    end)

    describe("Widget states", function()
        local Internal = Iris.Internal
        local widgetState

        beforeEach(function()
            widgetState = Internal._widgetState({ ID = "TestWidget", type = "Test" }, "value", 0)
        end)

        afterEach(function()
            Internal._states[widgetState.ID] = nil
            Internal._discardedStates[widgetState.ID] = nil
        end)

        it("SHOULD be kept while a widget is connected", function()
            Internal._releaseState(widgetState)
            expect(Internal._discardedStates[widgetState.ID]).to.equal(nil)
            Internal._collectStates()
            expect(Internal._states[widgetState.ID]).to.equal(widgetState)
        end)
        it("SHOULD be kept shortly after the widget is discarded", function()
            widgetState.ConnectedWidgets["TestWidget"] = nil
            Internal._releaseState(widgetState)
            expect(Internal._discardedStates[widgetState.ID]).to.equal(widgetState)

            Internal._collectStates()
            expect(Internal._states[widgetState.ID]).to.equal(widgetState)
        end)
        it("SHOULD be removed once the lifetime has passed", function()
            widgetState.ConnectedWidgets["TestWidget"] = nil
            Internal._releaseState(widgetState)
            widgetState.discardedTick -= Internal._stateLifetime + 1

            Internal._collectStates()
            expect(Internal._states[widgetState.ID]).to.equal(nil)
            expect(Internal._discardedStates[widgetState.ID]).to.equal(nil)
        end)
        it("SHOULD be reused if a widget reconnects in time", function()
            widgetState.ConnectedWidgets["TestWidget"] = nil
            Internal._releaseState(widgetState)

            local reused = Internal._widgetState({ ID = "TestWidget", type = "Test" }, "value", 1)
            expect(reused).to.equal(widgetState)
            expect(Internal._discardedStates[widgetState.ID]).to.equal(nil)
        end)
        it("SHOULD be kept if a function is connected to it", function()
            widgetState:onChange(function() end)
            widgetState.ConnectedWidgets["TestWidget"] = nil
            Internal._releaseState(widgetState)
            widgetState.discardedTick -= Internal._stateLifetime + 1

            Internal._collectStates()
            expect(Internal._states[widgetState.ID]).to.equal(widgetState)
        end)
        it("SHOULD never remove a user state", function()
            Internal._releaseState(state)
            expect(Internal._discardedStates[state.ID]).to.equal(nil)
            Internal._collectStates()
            expect(Internal._states[state.ID]).to.equal(state)
        end)
    end)
end
