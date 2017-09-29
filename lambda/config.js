// NOTE: the gmResize is the actual resize command for imagemagick.
// Check the docs: http://www.imagemagick.org/Usage/resize/
module.exports = [
    { gmResize: "810x810", "filenameSuffix": "" },
    { gmResize: "405x405", "filenameSuffix": "_thumb" },
    { gmResize: "150x150", "filenameSuffix": "_avatar" },
];
