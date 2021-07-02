pragma solidity >=0.4.25 <0.6.0;

library StringExtend {
    function cmp(string old, string value) pure internal returns (bool) {
        bytes memory _old = bytes(old);
        bytes memory _value = bytes(value);
        if(_old.length != _value.length) {
            return false;
        }else{
            for(uint i = 0; i < _old.length;i++) {
                if( _old[i] != _value[i]) {
                    return false;
                }
            }
            return true;
        }
    }

    function concat(string old,string value) pure internal returns(string) {
        bytes memory _old = bytes(old);
        bytes memory _value = bytes(value);
        bytes memory _ret = new bytes(_old.length + _value.length);
        for(uint i = 0;i<_old.length;i++) {
            _ret[i] = _old[i];
        }
        for(uint j = 0;j<_value.length;j++){
            _ret[_old.length+j] = _value[j];
        }
        return string(_ret);
    }
}
