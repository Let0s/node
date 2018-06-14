var assert = require('assert');
var testGlobal = {
    testProperty: () => {
        assert.ok(Five, 'property Five is undefined');
        assert.strictEqual(Five, 5, 'property Five is not equal to 5');
    },
    testField: () => {
        assert.ok(Four, 'property Four is undefined');
        assert.strictEqual(Four, 4, 'field Four doesnt equal ');
        var setterResult = 0;
        setterResult = Four = 5;
        assert.strictEqual(Four, 5, 'setter for Four field doesnt work');
        assert.strictEqual(setterResult, 5,
            'setter for Four field doesnt return result value');
    },
    testFunction: () => {
        assert.ok(typeof CreateRandomFigure == 'function',
            `CreateRandomFigure is not function, but ${typeof CreateRandomFigure}`);
        assert.ok(typeof CreateRectangle == 'function',
            `CreateRectangle is not function, but ${typeof CreateRectangle}`);
        assert.ok(typeof CreateCircle == 'function',
            `CreateCircle is not function, but ${typeof CreateCircle}`);
    },
    testEvent: () => {
        var figures = [];
        OnGetFigure = function (fig) {
            if (fig)
                figures.push(fig);
        }
        assert.notStrictEqual(figures.indexOf(CreateRandomFigure()), -1,
            'callback OnGetFigure does not work with CreateRandomFigure()');
        assert.notStrictEqual(figures.indexOf(CreateCircle(5)), -1,
            'callback OnGetFigure does not work with CreateCircle()');
        assert.notStrictEqual(figures.indexOf(CreateRectangle()), -1,
            'callback OnGetFigure does not work with CreateRectangle()');
        OnGetFigure = null;
    }
}

module.exports = testGlobal;