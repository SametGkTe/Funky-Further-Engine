# Third-party notices

## Psych Engine and Psych Engine Mobile

Further Engine is based on Psych Engine and its mobile ports. See the repository README and source headers for their contributors and licenses.

## FPS Plus reference assets

Parts of the V-Slice/FPS Plus presentation layer are adapted from community FPS Plus implementations. Existing provenance comments in the related source files remain applicable.

## NovaFlare Engine performance reference

The controlled loading-worker policy and safe cache-lifecycle approach added to Further Engine were informed by the open-source implementation in:

- [NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine](https://github.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine)
- Revision examined: `e5dd183`

Further Engine does not include NovaFlare's custom NovaGC Haxe/hxcpp toolchain, renderer overrides, private analytics integration, or engine branding. The adapted implementation was rewritten for Further Engine's existing Psych 1.0.4/mobile architecture.

See [`PERFORMANCE_PORT_TR.md`](PERFORMANCE_PORT_TR.md) for the technical compatibility analysis.
