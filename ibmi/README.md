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

## Setup

- See the 
  [setup guide](https://coderflow.ai/docs/ibmi/reference-app)
  for instructions on importing this example setup into CoderFlow.

## Example Task Prompts

### Hello World

```
Complete the Hello World program by outputting a message to the screen based on the user input. Add an option to the menu to launch the program.
```

### Real Programming Task w/Multiple Dependencies

```
Extend the "work with customers" program to add a new option "2=Edit". This option will call the "work with customers - detail" program in edit mode and allow the user to edit the customer and update the DB. The record should be updated when the user presses Enter.
```

### Generate New Application w/Multiple Dependencies

```
Explore the database tables to learn about the structure, then add a Work with Orders application:

The application should have a subfile list similar to the Work with Customers application.
The subfile should have a 5=Display option to view the order header.
Add an option to the menu to launch the application.
```

### Menu Modification

```
Add an option to the menu to launch the Hello World example program.
```
