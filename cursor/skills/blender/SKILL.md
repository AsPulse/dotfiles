---
name: blender
description: Drive Blender through the blender-cli command. Use when asked to model, edit a scene, render, inspect a .blend file, or when Blender work should be split across several independent instances (one per subagent).
---

# Blender

`blender-cli` drives running Blender instances over the Blender Lab add-on's TCP
socket. No MCP server is involved: the port is an argument, so any number of
instances can be driven independently.

## Resolve a port first

Never assume a port. Start from:

```
blender-cli ls
```

- Nothing listed → `blender-cli spawn` starts a fresh instance and prints its port.
- A specific one → `blender-cli ensure --port 9876` starts it only if that port is idle.
- `blender-cli kill --port N` (or `--all`) shuts instances down.

Each instance has its own config directory, its own open .blend, and its own sway
workspace, so instances never share state.

## Run code

```
blender-cli exec --port 9876 'import bpy
print(sorted(o.name for o in bpy.data.objects))'
```

- Whatever the code prints comes back on stdout.
- A Python exception exits non-zero with the traceback on stderr.
- Use `--file script.py`, or `-` to read from stdin, for anything longer than a few lines.
- `--json` returns the add-on's raw reply instead.

## Look at the viewport

Screenshots go through a file rather than the wire:

```
blender-cli exec --port 9876 'import bpy
bpy.ops.screen.screenshot(filepath="/tmp/blender-9876.png")'
```

Then read that PNG back. It is full resolution — nothing is
downscaled to fit a message size limit.

For an actual render, set `bpy.context.scene.render.filepath`, call
`bpy.ops.render.render(write_still=True)`, and read the result the same way.

## Check the API before guessing

`blender-cli docs-path` prints a directory holding the Blender Python API
reference (`api/`) and the user manual (`manual/`) as RST. Search it instead of
guessing at signatures or enum values:

```
grep -rl "primitive_uv_sphere_add" "$(blender-cli docs-path)/api"
```

## One instance per subagent

Spawn first, then hand the port to the subagent in its prompt:

```
PORT=$(blender-cli spawn)
# then: "Your Blender instance is port $PORT. Drive it with blender-cli --port $PORT."
```

Never let two agents share a port — they would be editing one scene without
knowing about each other.

## Working inside Blender

- Inspect before mutating. Reading `bpy.data` / `bpy.context` is cheap; assuming a
  name or a collection layout is not.
- Respect the existing naming and collection structure.
- `bpy.ops` depends on the current mode and on which object is active. The active
  object and the selection are distinct, and operators change both as a side
  effect, so set them explicitly between calls.
- Update the dependency graph before reading evaluated values such as world
  matrices or modifier results.
- In edit mode go through `bmesh` rather than the mesh data API, and flush back to
  the mesh afterwards.
- Do not destructively change parts of a scene you were not asked to touch.
