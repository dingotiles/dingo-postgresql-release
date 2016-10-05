
### disaster-recovery errand supports buddy-broker derived services/plans

    A service/plan registered with buddy-broker will have GUIDs that
    are prefixed with the root service ID. So we now search thru all
    pages of /v2/services, looking for multiple services that
    have the GUID of or prefixed by the provided root service ID.
