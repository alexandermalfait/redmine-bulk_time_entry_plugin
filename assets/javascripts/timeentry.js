var TimeEntry = Class.create({
    initialize:function (container) {
        this.container = container;

        this.observeElements()

        this.setInitialValuesFromLastRecord()

        //focus the project pulldown by default
        if(this.getElement('select.project-select')) {
            this.getElement('select.project-select').focus()
        }

        this.startTimer()

        this.registerNagger()
    },

    observeElements:function () {
        if(this.getElement("input.jump-to-issue")) {
            //select an issue by number
            this.getElement("input.jump-to-issue").observe('keyup', function (event) {
                if(event.target.value) {
                    this.selectIssue(event.target.value)
                }
            }.bind(this))
        }

        if(this.getElement('select.project-select')) {
            //save the last selected project, update issues
            this.getElement('select.project-select').observe('change', function (event) {
                TimeEntry.lastValues.projectId = event.target.value
                this.updateIssues()
            }.bind(this))
        }

        if(this.getElement('input.only-my-issues-checkbox')) {
            //save the last filter checkbox values, update issues
            this.getElement('input.only-my-issues-checkbox').observe('click', function (event) {
                TimeEntry.lastValues.onlyMyIssues = event.target.checked
                this.updateIssues()
            }.bind(this))
        }

        if(this.getElement('input.no-closed-issues-checkbox')) {
            this.getElement('input.no-closed-issues-checkbox').observe('click', function (event) {
                TimeEntry.lastValues.noClosedIssues = event.target.checked
                this.updateIssues()
            }.bind(this))
        }

        //save the last date
        this.getElement('input.spent_on').observe('change', function (event) {
            TimeEntry.lastValues.lastSpentOnDate = event.target.value
        })

        //observe the cancel button
        this.getElement('button.cancel-button').observe('click', function (event) {
            event.stop()
            this.cancel()
        }.bind(this))

        //obverse the toggle timer button
        this.getElement('button.toggle-timer-button').observe('click', function (event) {
            event.stop()

            this.toggleTimer()
        }.bind(this))

        //when the form is submitted, the HTML element will disappear, so remove this entry
        this.container.up('form').observe('submit', function () {
            this.remove()
        }.bind(this))
    },

    bindIssueSelectorToLink:function () {
        var issueSelector = this.getElement('select.issue-select')

        if(issueSelector) {
            issueSelector.observe('change', function () {
                this.setIssueLinkUrl();
            }.bind(this))
        }
    },

    setIssueLinkUrl:function () {
        var issueLink = this.getElement('a.issue-link')
        var issueSelector = this.getElement('select.issue-select')

        if(issueSelector.value > 0) {
            issueLink.writeAttribute("href", "/issues/" + issueSelector.value)
            issueLink.writeAttribute("target", "_blank")
        }
        else {
            issueLink.writeAttribute("href", "")
            issueLink.writeAttribute("target", "")
        }
    },

    setInitialValuesFromLastRecord:function () {
        if(! this.getElement('input.preselected-issue-id')) {
            if(TimeEntry.lastValues.projectId) {
                this.getElement('select.project-select').value = TimeEntry.lastValues.projectId
            }

            this.getElement('input.only-my-issues-checkbox').checked = TimeEntry.lastValues.onlyMyIssues
            this.getElement('input.no-closed-issues-checkbox').checked = TimeEntry.lastValues.noClosedIssues
            this.getElement('input.spent_on').value = TimeEntry.lastValues.lastSpentOnDate

            this.updateIssues()
        }
    },

    updateIssues:function () {
        var params = {
            project_id:$F(this.getElement('select.project-select')),
            entry_id:this.container.id
        }

        if(this.getElement('input.only-my-issues-checkbox').checked) {
            params.assigned_to_id = TimeEntry.defaultUserId
        }

        if(this.getElement('input.no-closed-issues-checkbox').checked) {
            params.only_open = true
        }


        console.log(this.getElement('.issue-selector-container'))

        new Ajax.Updater(this.getElement('.issue-selector-container'), TimeEntry.loadIssuesUrl, {
            parameters:params,
            method: "get",
            onComplete:function () {
                this.bindIssueSelectorToLink()
            }.bind(this)
        })
    },

    selectIssue:function (issueId) {
        var selector = this.container.down('select.issue-select')

        if(selector) {
            selector.value = issueId;

            this.setIssueLinkUrl()
        }
    },

    toggleTimer:function () {
        if(this.timer == null) {
            this.startTimer()
        }
        else {
            this.stopTimer()
        }
    },

    startTimer:function () {
        this.stopAllTimers()

        var hoursInput = this.getElement('input.hours-input')

        hoursInput.setStyle({ backgroundColor:"#acfbc1", border:"1px solid green" })

        this.timedMinutes = this.convertDecimalHoursToMinutes(hoursInput.value)

        this.getElement('button.toggle-timer-button').innerHTML = TimeEntry.language.stop_timer

        this.timer = new PeriodicalExecuter(function () {
            this.timedMinutes++;
            this.updateHoursField()
        }.bind(this), 60)
    },

    stopTimer:function () {
        if(this.timer != null) {
            this.timer.stop()
            this.timer = null
        }

        this.getElement('button.toggle-timer-button').innerHTML = TimeEntry.language.start_timer

        this.getElement('input.hours-input').setStyle({ backgroundColor:"#faadb6", border:"1px solid red" })
    },

    stopAllTimers:function () {
        TimeEntry.entries.each(function (entry) {
            entry.stopTimer()
        })
    },

    updateHoursField:function () {
        this.getElement('input.hours-input').value = this.convertMinutesToDecimalHours(this.timedMinutes)
    },

    convertMinutesToDecimalHours:function (minutes) {
        return Math.round((minutes / 60) * 100) / 100
    },

    convertDecimalHoursToMinutes:function (hours) {
        if(!hours) {
            return 0;
        }

        return parseFloat(hours) * 60
    },

    save:function () {
        this.getElement('button.save-button').click()
    },

    cancel:function () {
        if(confirm(TimeEntry.language.are_you_sure)) {
            this.container.up('form').remove()
            this.remove()
        }
    },

    remove:function () {
        TimeEntry.entries = TimeEntry.entries.without(this)

        if(this.timer != null) {
            this.timer.stop()
            this.timer = null
        }
    },

    getElement:function (cssClass) {
        return this.container.down(cssClass)
    },

    registerNagger:function () {
        Event.observe(window, 'beforeunload', function (event) {
            if($$('.time-entry').length > 0) {
                event.returnValue = "You have unsaved time entries, are you sure you want to close the page?"
            }
        });
    }
})

//static TimeEntry values and methods:

TimeEntry.lastValues = {
    projectId:null,
    onlyMyIssues:true,
    noClosedIssues:true,
    lastSpentOnDate:null //this one is set from ruby
}

TimeEntry.language = { }

TimeEntry.entries = []

TimeEntry.saveAllEntries = function () {
    this.entries.each(function (entry) {
        entry.save()
    })
}

TimeEntry.updateTodayEntries = function() {
    new Ajax.Updater('time-entries-today', TimeEntry.timeEntriesTodayUrl)
}