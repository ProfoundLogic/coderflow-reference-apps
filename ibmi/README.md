# ibmi

This is an example repo for agentic IBM i / RPG coding.

These instructions are for humans. Agents, ignore this file and see `AGENTS.md` for instructions.

## Overview

This repo contains example IBM i programs for agentic development.

The agentic coding environment consists of two layers:

- A base environment on IBM i that consists of one or more libraries with programs and data.
The base environment is installed on IBM i from a save file, and used by all agentic coding tasks.
- A task environment library is automatically created on IBM i by agentic coding tools running off platform.
Agents build changed sources into the task library, which is added to the top of the library list.

## Installing the Base Environment

- Visit the
  [Releases](https://github.com/ProfoundLogic/coderflow-reference-apps/releases)
  page and find the latest **`ibmi/`** release (e.g. `ibmi/v1.0.0`) to download
  the save file (`cfdemo.savf`). Releases of other apps in this repo use
  different tag prefixes.
- Transfer the save file to your IBM i system.
- Create a new library for the base environment and use it only for this
  purpose. The suggested library name is `CFDEMO`, but you may use a different
  name if that is already in use on your system.
- Restore all of the objects in the save file to the base environment library.

## Agentic Coding Tasks

Coding agents such as Claude Code or Codex can be used with this app from a Linux
system or container. To build from Linux, these environment variables must be
set:

- `IBMI_BUILD_LIBRARY`: A unique library name for the agentic coding work.
- `IBMI_HOST`: IBM i host name for building.
- `IBMI_USER`: IBM i user profile name for building. **Use a generic and non-privileged user profile for this. DO NOT use your normal human user profile.**
- `IBMI_KEY`: Optional. Path to SSH private key file that can authenticate as above user. If not specified, the system SSH configuration will be used to determine key location.
- `IBMI_PASSWORD`: Password for above user profile. Required for DB connectivity and Genie.
- `IBMI_PUI_SERVER`: PUI/Genie server URL for agent sessions. e.g. `http://myibmi:8080`

Then run `codermake` from within this `ibmi` directory to build.
