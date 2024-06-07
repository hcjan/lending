module lending_protocol::utils {

     public fun pow_u256(n: u256, e: u256): u256 {
        if (e == 0) {
            1
        } else {
            n * pow_u256(n, e - 1)
        }
    }
    

}