var assert = require('assert');
var testClasses = {
    testCircle: ()=>{
        var circle = CreateCircle(5);
        assert.ok(circle, 'circle is undefined');
        assert.strictEqual(Math.round(circle.Radius), 5, 'circle radius is not 5');
        var center = circle.Center;
        assert.ok(center, 'circle center is undefined');
        var center = {
            x : 4
        }
        circle = CreateCircle(center, 5);
        center = circle.Center;
        assert.ok(center, 'circle center is undefined');
        assert.strictEqual(Math.round(center.x), 4, 'circle center x is not 4');
    },
    testRectangle: ()=>{
        var rect = CreateRectangle({x: 0, y: 0}, {x: 10, y: 10});
        assert.ok(rect, 'rect is undefined');
        assert.strictEqual(rect.GetSquare(), 100, 'rect\'s square is not 100');

    },
    testEvent: ()=>{
        var fig = CreateCustomFigure();
        var callbackCalled = false;
        fig.OnGetSquare = (f)=>{            
            callbackCalled = true;
            assert.ok(f, 'first callback argument is undefined');
            assert.ok(fig == f, 'figure is not equal to first callback argument');
            return 23;
        }
        assert.strictEqual(fig.GetSquare(), 23, 'figure square is not 23');
    }
}

module.exports = testClasses;