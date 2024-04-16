public interface BankSzamla {
    void betesz(double osszeg);
    void kivesz(double osszeg) throws InsufficientFundsException;
    double egyenleg();
}
