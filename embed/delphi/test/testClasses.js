var assert = require('assert');
var testClasses = {
    testClass: () => {
        var circle = CreateCircle(5);
        assert.ok(circle, 'circle is undefined');
    },
    testClassProperty: () => {
        var circle = CreateCircle(5);
        assert.strictEqual(Math.round(circle.Radius), 5, 'circle radius is not 5');
    },
    testRecord: () => {
        var center = {
            x: 4
        }
        var circle = CreateCircle(center, 5);
        center = circle.Center;
        assert.ok(center, 'circle center is undefined');
        assert.strictEqual(Math.round(center.x), 4, 'circle center x is not 4');
    },
    testClassFunction: () => {
        var rect = CreateRectangle({ x: 0, y: 0 }, { x: 10, y: 10 });
        assert.ok(rect, 'rect is undefined');
        assert.strictEqual(rect.GetSquare(), 100, 'rect\'s square is not 100');
    },
    testClassEvent: () => {
        var fig = CreateCustomFigure();
        var callbackCalled = false;
        fig.OnGetSquare = (f) => {
            callbackCalled = true;
            assert.ok(f, 'first callback argument is undefined');
            assert.ok(fig == f, 'figure is not equal to first callback argument');
            return 23;
        }
        assert.strictEqual(fig.GetSquare(), 23, 'figure square is not 23');
        assert.ok(callbackCalled, 'callback was not called');
    },
    testStaticArray: () => {
        var rect = CreateRectangle({ x: 0, y: 0 }, { x: 10, y: 10 });
        var points = rect.AsPoints();
        assert.ok(points, 'rect points are not defined');
        assert.strictEqual(points.length, 2, `points length is not 2`);
        assert.ok(Math.round(points[0].x) == 0, 'first point x is not 0');
        assert.ok(Math.round(points[0].y) == 0, 'first point y is not 0');
        assert.ok(Math.round(points[1].x) == 10, 'second point x is not 10');
        assert.ok(Math.round(points[1].y) == 10, 'second point y is not 10');
    },
    testDynamicArray: () => {
        const sizes = [2, 5, 8, 10];
        const rects = CreateRectangles(sizes);
        assert.ok(rects, 'rects is not defined');
        assert.strictEqual(rects.length, sizes.length,
            'rects have different length than sizes');
        for (var i = 0; i < sizes.length; i++){
            assert.strictEqual(Math.round(rects[i].GetSquare()), 
                Math.round(sizes[i] * sizes[i]), 
                `rect${i}'s square is not equal to its size`);
        }
    }
}

module.exports = testClasses;