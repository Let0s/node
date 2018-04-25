var testClasses = {
    testCircle: ()=>{
        var circle = CreateCircle(5);
        if (!circle){
            throw new Error('circle is undefined');
        }
        if (Math.round(circle.Radius) != 5){
            throw new Error('circle radius is not 5');
        }
        var center = circle.Center;
        if (!center){
            throw new Error('circle center is undefined')            
        }
        circle.Center = {
            x : 5
        }
        var center = circle.Center;
        if (!center){
            throw new Error('circle center is undefined')            
        }
        if (Math.round(center.x) != 5){
            throw new Error('circle center x is not 5')
        }
    }
}

module.exports = testClasses;