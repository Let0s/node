var testGlobal = {
    testProperty: ()=>{
        if (!Five){
            throw new Error('property Five is undefined');
        }
        if (Five !== 5){
            throw new Error('property Five doesnt equal 5');
        }
    },
    testField: ()=>{
        if (!Four){
            throw new Error('field Four is undefined')
        }
        if (Four !== 4){
            throw new Error('field Four doesnt equal 4');
        }
        var setterResult = 0;
        setterResult = Four = 5;
        if (Four !== 5){
            throw new Error('setter for Four field doesnt work');
        }
        if (setterResult !== 5){
            throw new Error('setter for Four field doesnt return result value');
        }
    }
}

module.exports = testGlobal;