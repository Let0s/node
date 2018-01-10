var testClasses = {
    testProperties : function () {
        var success = true;
        try {
            if (obj.prop == '') {
                throw new Error('property prop is not defined')
            }
            if (obj.childProp == '') {
                throw new Error('property childProp is not defined')
            }
        }
        catch (e) {
            success = false;
            console.error(e);
        }
        return success;
    },
    testClassMethods : function () {
        var success = true;
        try {
            TTestParent.prototype.show();
            TTestChild.prototype.show();
        }
        catch (e) {
            success = false;
            console.error(e);
        }
        return success
    },
    testInheritance : function () {
        var success = true;
        try {
            if (!(obj instanceof TTestParent)) {
                throw new Error('object is not instance of parent class')
            }
            if (!(obj instanceof TTestChild)) {
                throw new Error('object is not instance of child class')
            }
        }
        catch (e) {
            success = false;
            console.error(e);
        }
        return success;
    }
}

module.exports = testClasses;