# GitHub Issue Templates & Detection Logic

## Templates

### 1. Bug Report / Issue Template

```
**Helpscout Ticket or WordPress Forum link**: 
<!--- Remove section if irrelevant. -->


## Expected Behavior
<!--- Tell us what should happen. -->


## Current Behavior
<!--- Tell us what happens instead of the expected behavior. -->


## Possible Solution
<!--- Not required, but suggest a fix/reason for the bug. -->


## Steps to Reproduce
<!--- Provide a link to a live example, or an unambiguous set of steps to reproduce this bug. Include code to reproduce, if relevant. -->
1.
2.
3.


## Screenshots
<!--- Remove section if no screenshots to share. -->
<!--- Include screenshots of the console if JS errors are present. -->
```

### 2. Enhancement / Improvement Template

```
## Expected Behavior
<!--- Tell us how it should work. -->


## Current Behavior
<!--- Explain the difference from the current behavior. -->


## Screenshots
<!--- Remove section if no screenshots to share. -->
```

### 3. New Feature Template

```
| What | Where |
| ---- | ----- |
| Asana | link |
| Design | Figma |

## Description
<!--- If this feature doesn't have a pitch, provide here all the relevant information: why it's needed, who will use it etc. Be as concise and descriptive as possible. -->

## Screenshots
<!--- Remove this section if irrelevant. Share here any mockups/screenshots that you have. -->
```

---

## Issue Type Detection Logic

Analyze the context to identify keywords and phrases that indicate the issue type. If multiple types are suggested, prioritize based on the most specific or dominant context.

- **Bug Report / Issue Keywords:** "bug report", "issue", "problem", "error", "defect", "not working", "unexpected behavior", "crash", "broken", "fault", "glitch", "incorrect output", "doesn't function".
- **Enhancement / Improvement Keywords:** "enhancement", "improvement", "optimize", "refactor", "improve", "make it better", "streamline".
- **New Feature Keywords:** "new feature", "add functionality", "introduce", "create a new".

---

## Information Extraction Rules

Once the issue type is determined, extract relevant information to populate the corresponding template fields. Be precise and avoid hallucinating information not present in the user's input or the dev notes.

### For Bug Report / Issue Template:

- **Helpscout Ticket or WordPress Forum link**: Leave as-is in the template — the full URL will be added manually later.
- **Expected Behavior**: Extract sentences that describe the desired or correct outcome.
- **Current Behavior**: Extract sentences that describe what is actually happening, which deviates from the expected behavior.
- **Possible Solution**: Extract any suggestions for a fix, a workaround, or a potential cause of the bug.
- **Steps to Reproduce**: Extract clear, sequential steps that lead to the bug. Format as a numbered list.
- **Screenshots**: Populate with labeled frame screenshots from the Figma designs.

### For Enhancement / Improvement Template:

- **Expected Behavior**: Extract sentences describing the desired new or improved functionality.
- **Current Behavior**: Extract sentences explaining how the current system or feature behaves and how it differs from the proposed enhancement.
- **Screenshots**: Populate with labeled frame screenshots from the Figma designs.

### For New Feature Template:

- **What / Where (Asana, Design)**: Populate Asana with the PM link if provided. Populate Design with the Figma subsection link.
- **Description**: Extract the comprehensive explanation of the new feature, including its purpose, the problem it solves, who the target users are, and its benefits. Synthesize from dev notes and screen context. Organize by screen state (Not Connected, Connected, Error, etc.).
- **Screenshots**: Populate with labeled frame screenshots from the Figma designs.

---

## Title Generation Logic

Generate a concise and descriptive title for each GitHub issue.

**General Guidelines:**
- **Conciseness:** Aim for 5-10 words.
- **Clarity:** The title should immediately convey the main subject.
- **Accuracy:** It must accurately represent the content.
- **Keywords:** Incorporate key terms that define the issue.

**Per Issue Type:**

- **Bug Report / Issue Title:**
  - Focus on the Current Behavior and Expected Behavior.
  - Identify the core problem and the affected component.
  - Examples: "[Component] [Action] is not [Expected Result]", "[Feature Name] - [Specific Issue]"

- **Enhancement / Improvement Title:**
  - Focus on the Expected Behavior (the desired improvement).
  - Examples: "Improve [Feature Name] by [Benefit]", "Add ability to [Action]"

- **New Feature Title:**
  - Focus on the Description of the new feature.
  - Examples: "Implement [Core Functionality]", "Introduce [New Capability]"
