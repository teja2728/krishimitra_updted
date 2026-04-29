const fs = require('fs');

function walkDir(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(function(file) {
        file = dir + '/' + file;
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) { 
            results = results.concat(walkDir(file));
        } else {
            if (file.endsWith('.dart')) results.push(file);
        }
    });
    return results;
}

const files = walkDir('c:/Users/tejak/Documents/nish_krishi/Krishimitra1/lib');

files.forEach(f => {
    let content = fs.readFileSync(f, 'utf8');
    let original = content;
    content = content.replace(/mobileNumber/g, 'mobile');
    content = content.replace(/numberOfAcres/g, 'landSize');
    content = content.replace(/cropTypes/g, 'crops');
    
    // Also update SchemeType references
    // wait, scheme fields changed too:
    // basicInfo -> description
    // schemeName -> name
    // schemeType -> type
    // applicationLink -> applyLink
    // lastDate -> deadline
    content = content.replace(/basicInfo/g, 'description');
    content = content.replace(/schemeName/g, 'name');
    content = content.replace(/schemeType/g, 'type');
    content = content.replace(/applicationLink/g, 'applyLink');
    content = content.replace(/lastDate/g, 'deadline');

    if (content !== original) {
        fs.writeFileSync(f, content, 'utf8');
        console.log('Updated ' + f);
    }
});
console.log('Done!');
