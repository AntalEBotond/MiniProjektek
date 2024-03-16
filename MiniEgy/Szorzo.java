import java.util.Scanner;
public class Szorzo {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        System.out.print("Adj meg egy számot 1 és 10 között: ");
        int number = scanner.nextInt();

        if (number >= 1 && number <= 10) {
            for (int i = 1; i <= 10; i++) {
                System.out.println(number + " x " + i + " = " + (number * i));
            }
        } else {
            System.out.println("Hiba: A számnak 1 és 10 között kell lennie!!!!");
        }
    }
}
