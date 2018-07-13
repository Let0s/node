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
        var rect = CreateRectangle({ x: 0, y: 0 }, { x: 5, y: 5 });
        rect.ApplyPoints([{ x: 0, y: 0 }, { x: 10, y: 10 }, { x: 4, y: 8 }])
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
        for (var i = 0; i < sizes.length; i++) {
            assert.strictEqual(Math.round(rects[i].GetSquare()),
                Math.round(sizes[i] * sizes[i]),
                `rect${i}'s square is not equal to its size`);
        }
    },
    // Delphi RTTI joins array of arrays into one array,
    // so "array[0..2] of array[0..2] of integer" will be converted to JS as 
    // "array[0..8] of integer"
    testArrayOfArrays: () => {
        // 1. Check if getter works correct
        const defaultRot = [
            1, 0, 0,
            0, 1, 0,
            0, 0, 1
        ];
        var circle = CreateCircle(5);
        var rot = circle.Rotation
        assert.strictEqual(rot.length, defaultRot.length);
        for (var i = 0; i < rot.length; i++) {
            assert.strictEqual(defaultRot[i], rot[i],
                `rotation[${i}] value mismatch`);
        }
        // 2. Check if setter works correct
        const newRot = [
            0, 1, 0,
            -1, 0, 0,
            0, 0, 1
        ];
        circle.Rotation = newRot;
        var rot = circle.Rotation
        assert.strictEqual(rot.length, newRot.length);
        for (var i = 0; i < rot.length; i++) {
            assert.strictEqual(newRot[i], rot[i],
                `rotation[${i}] value mismatch`);
        }
    },
    testInterface: () => {
        const intf = CreateRandomFigure();
        assert.ok(intf, 'intf is not defined');
        assert.ok(typeof intf.GetSquare == 'function',
            'GetSquare of interface is not a function');
    },
    testClasstype: () => {
        var rect = CreateRectangle({ x: 0, y: 0 }, { x: 10, y: 10 });
        assert.ok(rect instanceof TTestRectangle,
            'rect is not instance of TTestRectangle class');
    },
    testInheritance: () => {
        var rect = CreateRectangle({ x: 0, y: 0 }, { x: 10, y: 10 });
        assert.ok(rect instanceof TTestFigure,
            'rect is not instance of parent: TTestFigure class');
    },
    testEnum: () => {
        var obj = CreateFigure(TTestFigureType.tftCircle);
        assert.ok(obj, 'obj is not defined');
        assert.ok(obj instanceof TTestCircle, 'obj is not TTestCircle');
    },
    testIndexedProperty: () => {
        var list = CreateFigureList();
        var fig = CreateCustomFigure();
        list.Add(fig);
        assert.strictEqual(list.Items[0], fig, 'figure is not equal to list[0]');
    },
    testDefaultIndexedProperty: () => {
        var list = CreateFigureList();
        var fig = CreateCustomFigure();
        list.Add(fig);
        assert.strictEqual(list[0], fig, 'figure is not equal to list[0]');
    }
}

module.exports = testClasses;