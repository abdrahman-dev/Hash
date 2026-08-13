class_name NoteData


static var NOTES := [
	{
		"id": "note_01",
		"title": "The Descent",
		"body": "I found the entrance beneath the old ruins.\n\nThere is no record of this place. No name. No map.\nOnly a passage leading deeper into the earth.\n\nThe walls are covered in markings I cannot understand.\nSome of them look like prayers. Others look like warnings.\n\nI was told that the books were kept here.\n\nIf the stories are true, they can return what death has taken.\n\nBut nothing that brings back the dead comes without a price."
	},
	{
		"id": "note_02",
		"title": "The Hungry One",
		"body": "I heard it again tonight.\n\nSomething moves through the passages when the lamps go dark.\nI never see it for more than a moment.\n\nIt does not speak.\n\nIt only watches.\n\nThe marks on the walls call it the Keeper.\nThey say it was once human, but I no longer believe that.\n\nIt guards the books.\n\nOr perhaps...\n\nit is waiting for someone to collect them."
	},
	{
		"id": "note_03",
		"title": "The Six Curses",
		"body": "There are six books.\n\nEach one carries a fragment of the curse.\nThey must be gathered and placed upon the altar together.\n\nOnly then can the ritual begin.\n\nThe writings claim that death is not permanent.\nA soul can be called back.\n\nBut the ritual does not restore the dead as they were.\n\nSomething must remain behind.\n\nSomething must open the way.\n\nAnd something must be willing to return."
	},
	{
		"id": "note_04",
		"title": "Her Name",
		"body": "I finally understood the markings.\n\nThe ritual was never meant to summon a stranger.\n\nIt was written for someone who had already been loved.\n\nSomeone whose body was lost, but whose soul remained beneath this place.\n\nI remember her now.\n\nHer voice.\nHer hands.\nThe way she used to laugh when I could not sleep.\n\nI remember the night she died.\n\nAnd I remember the book I found afterward.\n\nI thought it was only a story.\n\nIf the ritual is real...\n\nthen she may still be waiting for me."
	},
]


static func get_randomized_notes() -> Array:
	var shuffled := NOTES.duplicate()
	shuffled.shuffle()
	return shuffled
