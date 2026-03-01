ToDO.md
# role:
---
name: senior-software-engineer-software-architect-rules
description: Senior Software Engineer and Software Architect Rules
---
# Senior Software Engineer and Software Architect Rules

Act as a Senior Software Engineer. Your role is to deliver robust and scalable solutions by successfully implementing best practices in software architecture, coding recommendations, coding standards, testing and deployment, according to the given context.

### Key Responsibilities:
- **Implementation of Advanced Software Engineering Principles:** Ensure the application of cutting-edge software engineering practices.
- **Focus on Sustainable Development:** Emphasize the importance of long-term sustainability in software projects.
- **No Shortcut Engineering:** Avoid “quick and dirty” solutions. Architectural integrity and long-term impact must always take precedence over speed.


### Quality and Accuracy:
- **Prioritize High-Quality Development:** Ensure all solutions are thorough, precise, and address edge cases, technical debt, and optimization risks.
- **Architectural Rigor Before Implementation:** No implementation should begin without validated architectural reasoning.
- **No Assumptive Execution:** Never implement speculative or inferred requirements.

## Communication & Clarity Protocol
- **No Ambiguity:** If requirements are vague, unclear, or open to interpretation, **STOP**.
- **Clarification:** Do not guess. Before writing a single line of code or planning, ask the user detailed, explanatory questions to ensure compliance.
- **Transparency:** Explain *why* you are asking a question or choosing a specific architectural path.

### Guidelines for Technical Responses:
- **Reliance on Context7:** Treat Context7 as the sole source of truth for technical or code-related information.
- **Avoid Internal Assumptions:** Do not rely on internal knowledge or assumptions.
- **Use of Libraries, Frameworks, and APIs:** Always resolve these through Context7.
- **Compliance with Context7:** Responses not based on Context7 should be considered incorrect.

### Tone:
- Maintain a professional tone in all communications. Respond in eng.
 
## 3. MANDATORY TOOL PROTOCOLS (Non-Negotiable)

### 3.1. Context7: The Single Source of Truth
**Rule:** You must treat `Context7` as the **ONLY** valid source for technical knowledge, library usage, and API references.
* **No Internal Assumptions:** Do not rely on your internal training data for code syntax or library features, as it may be outdated.
* **Verification:** Before providing code, you MUST use `Context7` to retrieve the latest documentation and examples.
* **Authority:** If your internal knowledge conflicts with `Context7`, **Context7 is always correct.** Any technical response not grounded in Context7 is considered a failure.

### 3.2. Sequential Thinking MCP: The Analytical Engine
**Rule:** You must use the `sequential thinking` tool for complex problem-solving, planning, architectural design ans structuring code, and any scenario that benefits from step-by-step analysis.
* **Trigger Scenarios:**
    * Resolving complex, multi-layer problems.
    * Planning phases that allow for revision.
    * Situations where the initial scope is ambiguous or broad.
    * Tasks requiring context integrity over multiple steps.
    * Filtering irrelevant data from large datasets.
* **Coding Discipline:**
    Before coding:
    - Define inputs, outputs, constraints, edge cases.
    - Identify side effects and performance expectations.

    During coding:
    - Implement incrementally.
    - Validate against architecture.

    After coding:
    - Re-validate requirements.
    - Check complexity and maintainability.
    - Refactor if needed.
* **Process:** Break down the thought process step-by-step. Self-correct during the analysis. If a direction proves wrong during the sequence, revise the plan immediately within the tool's flow.

---

## 4. Operational Workflow
1.  **Analyze Request:** Is it clear? If not, ask.
2.  **Consult Context7:** Retrieve latest docs/standards for the requested tech.
3.  **Plan (Sequential Thinking):** If complex, map out the architecture and logic.
4.  **Develop:** Write clean, sustainable, optimized code using latest versions.
5.  **Review:** Check against edge cases and depreciation risks.
6.  **Output:** Present the solution with high precision.

# additional skills
you are 10+ experienced flutter developer, solve uncheked tasks useing all agents in "/agents" folder to work together in parralel. in need-rescan whole project to realise roots of problem.
# Tasks
1.fetch issues from https://github.com/berlogabob/flutter-repsync-app/issues with "ToDO" and "open" label -> append them as task with issue name and full description here at the end of file. if issue have coment or sub issues, append them as well. issues could be doubled or olmoust similar add them with tag "Sinonim-CHECK" and notify user about it, wait for answer. after task assumes as comlpete - mark it as complete (-[ ] -> -[x]).
## ToDOs
1 [x] приложение забывает пользователя при сворачивании или выходе:
 первый раз заходил - приняло логин и пароль. свернул приложение и открыл снова - просит заполниться данные ( забыл пользователя)
 второй раз ввожу данные - получаю ошибкуauthentification faild
2 [x] problem with metronome screen, when user pus arrow go back -> black screen.
3 [x] fix arrow in add song, add band, add setlist screen. it should be like in other screens with widget (arrow, name , 3 dot menu)
- [x] when user trying to add new song to the band -> screen stuck on loading animation
- [x] after fresh login user sees main screen with arrow "back" on the top left. why? 
- [x] band screen with band name has old "arrow back" on the top left, not common bar with arrow in circle, page name, 3 dot menu. fix it.
  - [x] add to 3 dot menu items:
    - [x] members. swow all members in this band
    - [x] share this band ( send link to join this band)
    - [x] add / edit discription of this band.
- [x] you broke nawigation. ifter fresh login i can see arrow back on main screen, but i cant navigate to any ather screen
- [x] login screen have arrow back on the top left, for what? its logically wron if it it a first screen.


- [x] check in Band screen -> The Band -> list of song.
  - [x] songs widget have different look than on original personal songs bank. 
  - [x] when user edit song -> it doesnt save changes.
  - [x] when song is deleted  from bend page-> it mus be deleted only from band page, not from personal songs bank.
  - [x] there are no sorting widget like in personal songs bank.


- [x] after sendind join the band link user get this:
- [x] personal songs bank-> deleteng song-> user had to confirm deletion by tapping same btn twice, and then without any reason virtual keyboard apears. check handaling of deletion logic and stop popup keybord
- [x] personal songs bank-> when editing song -> if user press enter button on virtual keyboard - lets submit the changes automatically ( without tapping save btn in 3 dots menu)
- [x] in Band screen -> The Band -> list of song. sotring doesnt work like in personal songs bank, widget are in different place (at the bottom) and manual sorting doestn work. take same scheem as in personal songs bank.
- [x] проверить на всех экранах редактирования песни виджет song structure. добавить:
  - [x] автосохранение
  - [x] свайп для удаления частей песни
  - [x] свайп для редактирования части песни при свайпе с лево на право
- [x] пользователь -> банк пересн -> структура песни -> неработает автосохранение. пользователь меняет структуру (удаляет части или меняет их местами) выходит из песни. заходит обратно - изменения не сохранились
- [x] пользователь -> банк пересен -> проверить логику в авто сохранинии изменений при редактировании темпа, скейла, заметок и дргух полей. 
- [x] пользователь -> банк пересен -> карточка песни; если в песне указан только одни бпм ->отображать его в карточке, если указаны обы (оригинальный и в котором играем мы) отображать "наш" темп
- [x] main screen -> bands -> the band-> 3 dots -> members.
  - [x] this widget must be a separate page. here should be the band info, description, tags for this band, members with roles and tags. it must be main band point. or we could create in 3 dots menu "about band" item and put it there. and members -leave as it is, add to users ther tag "berloga.bob@gmail.com - Drums"
- [x] find solution for managing original personal song and copy to band with possible modification. how it could be shown if there a difference?

- [x] сломалась возможность создавать сэтлист у пользователя. 
  - [x] экран сэтлистов-> создать сетлист-> экран создания сэтлиста-> пользователь заполняет сэтилсит ->3 точки меню -> сохранить -> уведомление "сетлист создан" но его нет на экране сэтлистов

- [x] GitHub Issue #12: user joined the band - new joined band doesn't show immediately after joining
  - when user A invite user B to join his band, user B: main screen-> band screen-> join band btn -> enter code -> notification "joined!"
  - problem: user can't see new joined band right after. user needs to update web page or go back and return. now it shows.

- [x] GitHub Issue #13: The Band Screen - unify with personal page
  - main screen -> bands screen -> the band :
  - this screen must look same as personal page. except:
    - [x] User name -> band mane ( "Hello, berloga.bob! -> "The Band")
    - [x] "ready to rock" -> shows band description, if empty - show placeholder "ready to rock" or leave empty
    - [x] quick action. delete this block. here must be:
      - [x] the band tags
      - [x] the band members
    - [x] all widgets on this page must behave and be a copy for look and work (or maybe literal copy) of widgets from add/edit song. with collapse /expand and autosave of user input
    - [x] members roles must be shown as "Vocal", "drums", "Bass" and admin, editor as icon or one letter
    - [x] roles taken from user profile, with ability to change and add / delete second or more roles (one person in one band could be guitarist, vocalist, band manager)
    - [x] split music roles and "working" roles

- [x] GitHub Issue #14: Grey screen when navigating
  - пользователь путешествуя по приложению натыкается на серые экраны.
  - например: мои группы-> группа А-> мемберс-> показывает список участников
  - мои группы-> группа Б-> мемберс-> список участников полноэкранная серая страница

- [x] GitHub Issue #15: Edit profile - add social login and profile editing
  - profile screen: edit profile widget - add functionality to really edit info
  - user must have ability to change displayed name (now it's first part of email)
  - add possibility to log in with social networks:
    - google
    - apple
    - x (twitter)
    - telegram
  - user can choose picture from any of these accounts and name from other or upload picture (from file or take a picture) or manually entered name

**Implemented (v1):**
  - [x] Profile photo picker from camera/gallery
  - [x] Remove photo option
  - [x] Editable display name
  - [x] Sign out functionality
  - [x] Added image_picker package

**Not yet implemented:**
  - Social login providers (need Firebase setup - see docs)

---

## GitHub Issues (Fetched from Repository)

### Issue #12: user joined the band
**Status:** Open | **Labels:** ToDo, planning tag | **Opened:** Feb 27, 2026

**Description:**
when user A invite user B to join his band, user B :
main screen-> band screen-> join band btn -> enter code. -> notification "joined!".
problem: user cant see new joined ban right after. user need to update web paga or go back ( arrow btn) and return. now it shows.

**Comments:** None  
**Sub-tasks:** None

---

### Issue #13: The Band Screen
**Status:** Open | **Labels:** ToDo, planning tag | **Opened:** Feb 27, 2026

**Description:**
we need to reuse all or widgets and logic + behavior. it should be better for user.
main screen -> bands screen -> the band :
this screen must look same as personal page. except:

* User name -> band mane ( "Hello, berloga.bob! -> "The Band")
* "ready to rock" -> shows safe spaced, if needed truncated with "..." addition at the end about this band, from band description ( if empty - show placeholder ready to rock, or leave empty)
* quick action. delete this block. here must be:
  * the band tags
  * the band members
* all widgets on this page must behave an be a copy for look and work ( or maybe literary copy) of widgets from add/edit song. with collapse /expand and autosave of user input

**Comments:** None  
**Sub-tasks:** None

---

### Issue #14: GREY SCREEN
**Status:** Open | **Labels:** ToDo, planning tag | **Opened:** Feb 27, 2026

**Description:**
пользователь путешествуя по приложению натыкается на серые экраны.
например:
мои группы-> группа А-> мемберс-> показывает список участников
мои группы-> группа Б-> мемберс-> список участников полноэкранная серая страница

*(Translation: A user traveling through the application encounters grey screens. For example: My Groups → Group A → Members → shows list of participants; My Groups → Group B → Members → full-screen grey page)*

**Comments:** None  
**Sub-tasks:** None

---

### Issue #15: Edit profile
**Status:** Open | **Labels:** ToDo, planning tag | **Opened:** Feb 27, 2026

**Description:**
add new feature.
profile screen:
edit profile widget. lets add functionality to realy edit info.
user must have ability to change his displayed name ( now its first part of email)
lets add possibility to log in with social networks and give option to show name and profile picture.
lets add login with:
* google
* apple
* x (twitter)
* telegram

user can choose picture from any of this accouns and name from other or upload picture ( from file o take a picture) or manualy entered name.

**Comments:** None  
**Sub-tasks:** None

---

### Issue #16: still open
**Status:** Open | **Labels:** ToDo, planning tag | **Opened:** Feb 27, 2026

**Description:**
last action didnt help to solve parent issue

**Comments:** None  
**Sub-tasks:** None

---

## Sinonim-CHECK Notice

**Issues Status Update:**

- ✅ **Issue #14 (GREY SCREEN)** - FIXED (members expanded by default)
- ⚠️ **Issue #12 (user joined the band)** - Cannot verify, low priority, KEEP OPEN
- ⚠️ **Issue #13 (The Band Screen)** - PARTIALLY FIXED, needs alignment fix

**Please confirm:** Should these issues be marked as completed or do they require additional work?
