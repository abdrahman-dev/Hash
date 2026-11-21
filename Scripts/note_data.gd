class_name NoteData

static var NOTES := [
	{
		"id": "note_01",
		"title": "The Descent",
		"body": "You were never meant to find this place.\n\nThere is no name for what lies beneath the ruins. No map leads here. No record remembers it.\n\nStill, the path was left open.\n\nThe walls remember those who came before you. Their words have faded, but the warnings remain.\n\nSix books are hidden below.\n\nDo not mistake them for books.\n\nThey were written for something that should not be remembered.\n\nIf you have already found one, the place has already noticed you.\n\nKeep going.\n\nYou have come too far to turn back now."
	},
	{
		"id": "note_02",
		"title": "The Hungry One",
		"body": "You have seen it.\n\nPerhaps only a shape in the dark.\nPerhaps only two eyes between the walls.\n\nDo not wait for it to show itself again.\n\nThe old markings give it many names.\nThe oldest one calls it the Keeper.\n\nDo not believe the stories about what it was.\n\nIt no longer belongs to the world above.\n\nIt knows what you are looking for.\n\nIt knows why you came.\n\nAnd it will know when you have found enough.\n\nIf you hear it close behind you, do not look back.\n\nThe first mistake was looking for the books.\n\nThe second would be believing they are the only thing being collected."
	},
	{
		"id": "note_03",
		"title": "The Six Curses",
		"body": "There are six.\n\nSix books.\nSix seals.\nSix pieces of something that was never meant to be whole again.\n\nThe markings beneath the ruins speak of an altar.\nThey speak of a door.\nThey speak of a voice calling from the other side.\n\nNone of them say what waits there.\n\nThat part was scratched away.\n\nOnly the warning remains:\n\nSomething must be left behind.\nSomething must open the way.\nAnd something must answer when it is called.\n\nIf all six books are gathered, the altar will know.\n\nSo will the thing beneath it.\n\nPerhaps that is why the Keeper is still here."
	},
	{
		"id": "note_04",
		"title": "Her Name",
		"body": "You know the name.\n\nYou knew it before you entered these halls.\n\nThat is why this place opened for you.\n\nThat is why the markings appeared where you could see them.\n\nThat is why the books were left where your hands would eventually find them.\n\nYou may have forgotten the face.\nYou may have forgotten the voice.\n\nThe place has not.\n\nSomewhere beneath the stone, something is still waiting.\n\nDo not ask whether it is alive.\n\nDo not ask whether it remembers you.\n\nWhen the six books are brought to the altar, you will have your answer.\n\nAnd when the door opens...\n\nremember who called you here."
	},
]


static func get_randomized_notes() -> Array:
	var shuffled := NOTES.duplicate()
	shuffled.shuffle()
	return shuffled
