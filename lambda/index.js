const util = require("./lib/util");

exports.handler = (event, context, callback) => {
    console.log("NEW EVENT ", JSON.stringify(event));
    const downloads = event.Records.map(r => util.getS3Image(r.s3.bucket.name, r.s3.object.key));
    Promise.all(downloads)
        .then(images => Promise.all(images.map(util.processImageWithConfigs)))
        .then(() => callback())
        .catch(err => {
            context.callbackWaitsForEmptyEventLoop = false;
            return callback(err || new Error("Failed to process image."));
        });
};
