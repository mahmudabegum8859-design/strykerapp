package com.opxdemon.terminal.frontend.session.terminal

import com.opxdemon.terminal.ui.term.TermTab

class CreateNewSessionEvent
class SwitchIndexedSessionEvent(val index: Int)
class SwitchSessionEvent(val toNext: Boolean)
class TabCloseEvent(val termTab: TermTab)
class TitleChangedEvent(val title: String)
class ToggleFullScreenEvent
class ToggleImeEvent
