﻿var testGlobal = {
    testFunction : function () {
        var success = true;
        try {
            Func('hello')
        }
        catch (e) {
            success = false;
            console.error(e);
        }
        return success;
    },
    testProp : function () {
        var success = true;
        try {
            var prevProp = Prop;
            if (!prevProp)
                throw new Error('Prop is not assigned');
            var newProp = Prop += 'modified';
            if (newProp !== Prop) {
                throw new Error('Setter result is not equal to Prop property');
            }
            if (newProp == prevProp) {
                throw new Error('Prop property wasn\'t changed');
            }
        }
        catch (e) {
            success = false;
            console.error(e);
        }
        return success;
    },
    testPropertyObject: function() {
        var success = true;
        try {
            if (!obj) {
                throw new Error('property obj is not assigned');
            }
        }
        catch (e) {
            success = false;
            console.error(e);
        }
        return success;

    }
}

module.exports = testGlobal;