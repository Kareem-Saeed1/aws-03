# AWS diagram assets

The editable `.drawio` file uses **native draw.io AWS shapes** (`mxgraph.aws4`), including resource icons, VPC, Region, subnet and Auto Scaling boundaries. It contains no embedded raster or SVG image objects. Service labels belong to the service shapes, connectors reference source/target shapes, and nested boundaries use parent-child containment.

Native shape identifiers were checked against the official [draw.io AWS palette source](https://github.com/jgraph/drawio/blob/dev/src/main/webapp/js/diagramly/sidebar/Sidebar-AWS4.js) and [AWS shape implementations](https://github.com/jgraph/drawio/blob/dev/src/main/webapp/shapes/mxAWS4.js). Open the file in a current version of [diagrams.net](https://app.diagrams.net/).

The companion PNG and SVG preview use original AWS artwork from the official **31 July 2026** architecture icon package to render the same topology in a conventional white-background layout.

- [AWS Architecture Icons and usage guidance](https://aws.amazon.com/architecture/icons/)
- [Official icon package](https://d1.awsstatic.com/onedam/marketing-channels/website/public/shared/architecture-icon-release/Icon-package_07312026.5846e92413caa21490223536cc97f1269e44fa92.zip)
- Retrieved: 19 October 2026.

Selected source assets in `aws-icons/` are unchanged except for local filenames. AWS artwork and trademarks remain subject to AWS terms, not the project MIT license. The native stencil appearance can vary slightly with the draw.io version. No image-generation model was used for the architecture artwork.

This diagram represents the repository design; it does not claim a live AWS deployment.
