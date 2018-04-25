var testClasses = {
    testCircle: ()=>{
        var circle = CreateCircle(5);
        if (!circle){
            throw new Error('circle is undefined');
        }
        if (Math.round(circle.Radius) != 5){
            throw new Error('circle radius is not 5');
        }
    }
}

module.exports = testClasses;