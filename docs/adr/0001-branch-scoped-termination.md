# Model selective stopping as process-tree branches

Status: accepted

Culprit models “stop only some of the stack” as a branch stop: one selected
process plus its observed descendants. It does not offer arbitrary PID
checkboxes, because selections that omit descendants are difficult to explain,
easy to misuse, and often leave orphaned helpers. The whole-stack action
remains the clear default; branch controls are progressive disclosure inside
the causal evidence view.
