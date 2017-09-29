const AWS = require("aws-sdk");
const im = require("gm").subClass({ imageMagick: true });
const imagemin = require("imagemin");
const imageminMozjpeg = require("imagemin-mozjpeg");
const imageminPngquant = require("imagemin-pngquant");
const RESIZE_CONFIGS = require("../config");

const s3 = new AWS.S3();

// this env variable is declared at the cloudformation template
const RESIZED_S3_BUCKET = process.env.RESIZED_S3_BUCKET;
const RESIZED_S3_BUCKET_CUSTOM_PATH = process.env.RESIZED_S3_BUCKET_CUSTOM_PATH || "";

// Downloads an image from s3 bucket
function getS3Image(bucketName, key) {
    return new Promise((resolve, reject) => {
        const originalKey = decodeURIComponent(key.replace(/\+/g, " "));
        s3.getObject({ "Bucket": bucketName, "Key": originalKey }, (err, data) => {
            if (err) { return reject(err); }
            resolve({
                originalKey: originalKey,
                contentType: data.ContentType,
                imageType: getImageType(data.ContentType),
                buffer: data.Body,
            });
        });
    });
}

// Given an image, process it with each config
function processImageWithConfigs(image) {
    return Promise.all(RESIZE_CONFIGS.map(config => {
        return resizeImageBuffer(image.buffer, config.gmResize, image.imageType)
            .then(buffer => compressImageBuffer(buffer))
            .then(buffer => {
                const key = getNewFileKey(config.filenameSuffix, image.originalKey);
                return uploadBufferToS3(buffer, key, image.contentType);
            });
    }));
}

function uploadBufferToS3(buffer, key, contentType) {
    return new Promise((resolve, reject) => {
        s3.putObject(
            { "Bucket": RESIZED_S3_BUCKET, "Key": key, "Body": buffer, "ContentType": contentType },
            (err) => (err ? reject(err) : resolve())
        );
    });
}

function resizeImageBuffer(buffer, resizeConfig, type) {
    return new Promise((resolve, reject) => {
        im(buffer).resize(resizeConfig).toBuffer(type, (err, buffer) => {
            if (err) { return reject(err); }
            return resolve(buffer);
        });
    })
}

function getImageType(type) {
    if (type === "image/jpeg") { return "jpeg"; }
    if (type === "image/png") { return "png"; }
    throw new Error("Unsupported object type " + type);
}

// Given a filename with extension, add a suffix to it. e.g.: file.jpg -> file_thumb.jpg
function getNewFileKey(filenameSuffix, filename) {
    const name = filename.replace(/\.[^/.]+$/, ""); // removes the extension if any
    const extension = filename.match(/(?:\.([^.]+))?$/g)[0]; // returns the extension with dot if any. e.g.: '.jpg'
    return `${RESIZED_S3_BUCKET_CUSTOM_PATH}${name}${filenameSuffix}${extension}`;
}

// Given an image buffer, spawn a process that runs cjpeg to compress it and resolves the buffer
function compressImageBuffer(buffer) {
    return imagemin.buffer(buffer, { plugins: [imageminMozjpeg({ progressive: true }), imageminPngquant({ quality: "70-80" })] });
}

module.exports = {
    getS3Image,
    processImageWithConfigs,
};