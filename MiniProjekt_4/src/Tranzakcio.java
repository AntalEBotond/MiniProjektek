import java.time.LocalDateTime;

public class Tranzakcio {
    private LocalDateTime idopont;
    private TranzakcioTipus tranzTipus;
    private double osszeg;

    public Tranzakcio(TranzakcioTipus tranzTipus, double osszeg) {
        this.idopont = LocalDateTime.now();
        this.tranzTipus = tranzTipus;
        this.osszeg = osszeg;
    }

    @Override
    public String toString() {
        return idopont.toString() + ": " + tranzTipus + " - " + osszeg + " HUF";
    }
}
