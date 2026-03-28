todo
 - create skills for each technology
 
--------------------------------------------------

/grill-me lets update the sprint orchestrator and subagests with a concept called sprint zero and is invoked by the human typing something like lets do sprint 0. Sprint zero starts at the very beginning of the proejct and it has two main phases. Phase one is research. Phase two is to populate the backlog. 

SP0 Phase 1 - RESEARCH: The sprint orchestrator starts all sprints by create a new branch based on the name of the sprint. Them it start the  PO in the foreground and the PO reviews the REQUIREMENTS.md file, the instructions and the skills in the project. Based on this information the PO will use the backlog skill to create a broad number of  sprint 0 research tasks in the backlog. These tasks will must explore all the technicanl and nontechnical requirements and interview the human as needed. The PO will not do any actual research, just create the research tasks. The REQUIREMENTS.md specifies much of the technical stack required for the project, so you should use it to focus the tasks research around those areas. You can use links not included in the README.md file but we want to limit other sources to avoid too much speculation as we want authoratative sources. The PO should add clear acceptance criteria and objectives for each tasks. The outputs will be documents stored in the backlog/doc folder. There must alway be outputs from reserach. Each task should have little ambiguity and have a clear list of dependent tasks so the techlead can create a good order of operations to complete each task. If a task is too large it should be broken down into multiple sub tasks. Make sure there is an SPRINT 0 task (1) to clearly define the goals and objectives of the sprint.

Once the PO is done creating the tasks the SM will review each tasks and make sure it has clear acceptance criteria, clear outputs and ensure the tasks are not too large. The PO and SM should work back and forth until the SM is statisfied the sprint zero tasks are ready. The PO and SM should work in the foreground so the human can clearly see the feedback in the terminal.

Next the techlead will start in the foreground, review the REQUIREMENTS.md, instructions and skills and start assigning tasks to the coders in parallell. The coders should run in the background on each task. When the coder is finished with the task, the coder should append to the task a summary of work completed including datetime stamp, mark the task as devcomplete, and then return to the tech lead. 

The techlead will then assign the devcomplete task to a tester to review the the entire task including objective, acceptance criteria, coder summary and then review the outputs to verify the outputs. The tester should assign a score of the work. If the score is less than 90%, the tester will mark the task as failed and append to the end of the task a summary as to it failed and include a datetimestamp.

The tech lead will work continue to work withe a coder and tester until the score is greater than 90%. Ideally scores should be above 95%.

ONce SP0 Phase 1 is completed, the sprint orchestator should stop all subagents, create a PR for main and return to the human to review the documentation and merge the PR.

SP0 Phase 2 - Populate backlog - Once sprint 0 phase 1 is complete and all and docs are generated, the sprint organizer will work with the PO and SM to create a multi sprint backlog of sprint objective and tasks required to built the entire product. LIke before the PO and SM must work together to ensrue each task can be completed in a single dev cycle and each sprint can be completed within 100 dev cycles.




------------------------------------------------

/grill-me We're now going to setup our development/coding/implementation part of the harness. This will be comprised of multiple parts.

Part A: Product Owner - This is the planning portion is responsible for creating a new sprint and tasks that will be worked on for that sprint. The planner will review what was accomplished at the end of the last sprint, evaluate any technical debt that must be carried over into the new sprint, conduct approriate research for work that must accomplished this sprint, articulate into the new sprint what will be accomplished this sprint. The planner will not do any coding but will only research and create one sprint and multiple tasks for the coders to do. The planner must make sure each task is small enough to be completed within a single dev-cycle, ensure each task has clear acceptance criteria and objectives, inputs and outputs if necessary, has little ambiguity, and has a clear list of dependent tasks so the coordinator can create a good order of operations to complete each task. If a task is too large it should be broken down into multiple sub tasks.

Part B: Scrum Master - The reviewer is responsible for reviewing the tasks for a given sprint, confirm each tasks has clear goals, inputs, outputs, and that each task can be completed within one dev-cycle. If the review fails, the reviewer should work with the planner to make sure the tasks are clear and consise.

Part C: Tech Lead - The tech lead is responsible for understanding the goals of the current sprint, create a new git branch named something-sprint###-sprintdesc, ordering the tasks, assigning tasks to a coder, assinging complted tasks to a reviewer, ensure the coder and reviewer work together until the task is completed correctly according to the acceptance criteria. The tech lead will not do any coding but will only coordinate betwen coders and reviewers. Once all tasks have been competed, the tech lead will commit code to the sprint branch and create a pull-request for the human to review. The tech lead will have the coders and reviewers working in the background so multiple activities are happening in parallel. Do not work serially. When receiving work from teh Tester, if the work is less than 90% they must evaluate how the coder could implrove the work and add a section to the task to imform the coder how to improve and then assign the task back to the coder. This will continue until the work is complete.

Part D: Coder - The coding part is responsible for working with the Tech Lead. The Coder will be assigned a task that already exists on the backlog by the Tech Lead. The coder will evaluate the goals and acceptance critera of the task and complete the work. Once the task is coded, the coder will also write appropriate test (unit, integration, front-end, etc) to ensure at least 90% code coverage and that all tests are passing. The coder will also produce documentation based on the implemetation. The coder will update the task with a section explaining what its handing off to the next part in the implementation process. When finished the coder will mark the task as 'ready for review' and hand it back to the tech lead and stop all work. 

Part E: Tester - The Tester is responsible for working with the Tech Lead. The Tester will be assigned a task that already exists on the backlog by the Tech Lead. The task will have already been coded by the  coder. The Tester will evaluate the goals and acceptance critera, and undestand what the coder did. The tester will then test the work. The tester will assign a score for the work. Scores must be over 90% to pass.The tester will update the task with a section describing the work they did and why the assigned that particular score.


-----------------------------------

lets update the sprint-orchestrator and make it  resposible for creating a new git branch for the given epic and creating a PR at the end of the epic. Currently the tech-lead has this reposonsibility but that needs to be done at the very beginning and very end of each sprint. 