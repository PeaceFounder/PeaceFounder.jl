import org.julialang

App {

    userDemes : _USER_DEMES

    onAddDeme : invite => Julia.addDeme(invite)

    onSetDeme : uuid => Julia.setDeme(uuid)

    onSetProposal : index => Julia.setProposal(index)

    onCastBallot : Julia.castBallot()


    onRefreshHome : Julia.refreshHome()

    onRefreshDeme : Julia.refreshDeme()

    onRefreshProposal : Julia.refreshProposal()

    onResetBallot : Julia.resetBallot()

    demeProposals : _DEME_PROPOSALS

    demeStatus {
        
        uuid : _DEME_STATUS.uuid
        title : _DEME_STATUS.title
        demeSpec : _DEME_STATUS.demeSpec
        memberIndex : _DEME_STATUS.memberIndex
        commitIndex : _DEME_STATUS.commitIndex
        memberCount : _DEME_STATUS.memberCount

    }


    proposalMetadata {

        index : _PROPOSAL_METADATA.index
        title : _PROPOSAL_METADATA.title
        description : _PROPOSAL_METADATA.description
        stateAnchor : _PROPOSAL_METADATA.stateAnchor
        voterCount : _PROPOSAL_METADATA.voterCount

    }
    
    proposalStatus {

        isVotable : _PROPOSAL_STATUS.isVotable
        isCast : _PROPOSAL_STATUS.isCast
        isTallied : _PROPOSAL_STATUS.isTallied
        timeWindowShort : _PROPOSAL_STATUS.timeWindowShort
        timeWindowLong : _PROPOSAL_STATUS.timeWindowLong
        castCount : _PROPOSAL_STATUS.castCount

    }

    proposalBallot : _PROPOSAL_BALLOT

    guardStatus {

        pseudonym : _GUARD_STATUS.pseudonym
        timestamp : _GUARD_STATUS.timestamp
        castIndex : _GUARD_STATUS.castIndex
        commitIndex : _GUARD_STATUS.commitIndex
        commitRoot : _GUARD_STATUS.commitRoot

    }

}
